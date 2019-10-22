package 
{
	import com.greensock.TweenLite;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	import mx.core.FlexGlobals;
	
	import device.Device;
	import device.RunningDevice;
	import device.running.AndroidDevice;
	import device.running.IosDevice;
	import device.running.IosDeviceInfo;
	import device.simulator.IosSimulator;
	
	import net.tautausan.plist.PDict;
	import net.tautausan.plist.Plist10;
	
	public class RunningDevicesManager
	{
		private const mobileDevice:File = File.applicationDirectory.resolvePath("assets/tools/ios/mobiledevice");
		private const systemProfiler:File = new File("/usr/sbin/system_profiler");
		private const envFile:File = new File("/usr/bin/env");
		
		private const sysprofilerArgs:Vector.<String> = new <String>["system_profiler", "SPUSBDataType", "-xml"];
		private const simCtlArgs:Vector.<String> = new <String>["xcrun", "simctl", "list", "devices", "-j"];
		private const adbArgs:Vector.<String> = new <String>["devices"];
						
		private const adbPath:String = "assets/tools/android/adb";
		private const iosDevicePattern:RegExp = /(.*)\(([^\)]*)\).*\[(.*)\](.*)/
		private const jsonPattern:RegExp = /\{[^]*\}/;
		
		private const relaunchDelay:int = 1;
				
		private var adbFile:File;
		
		private var androidOutput:String;
		private var iosOutput:String;
		
		private var relaunchAdb:TweenLite;
		private var relaunchIos:TweenLite;
		
		private var port:String = "8080";
						
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		public static var devTeamId:String = "";
		
		private var usbDevicesIdList:Vector.<String>;
		
		public function RunningDevicesManager(port:String, macos:Boolean)
		{
			this.port = port;
			
			if(macos){
				
				relaunchIos = TweenLite.delayedCall(relaunchDelay, launchIosProcess);
				
				this.adbFile = File.applicationDirectory.resolvePath(adbPath);
				
				var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				procInfo.executable = new File("/bin/chmod");			
				procInfo.workingDirectory = File.applicationDirectory.resolvePath("assets/tools");
				procInfo.arguments = new <String>["+x", "android/adb", "ios/mobiledevice"];
				
				var proc:NativeProcess = new NativeProcess();
				proc.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
				proc.start(procInfo);
				
			}else{
				this.adbFile = File.applicationDirectory.resolvePath(adbPath + ".exe");
				relaunchAdb = TweenLite.delayedCall(relaunchDelay, launchAdbProcess);
			}
		}
		
		protected function onChmodExit(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onChmodExit);
			relaunchAdb = TweenLite.delayedCall(relaunchDelay, launchAdbProcess);
		}	
		
		public function terminate():void{
			var dv:RunningDevice;
			for each(dv in collection){
				dv.close();
			}
			
			relaunchAdb.pause();
			if(relaunchIos != null){
				relaunchIos.pause();
			}
		}
		
		private function launchAdbProcess():void{
			
			androidOutput = "";
			
			var proc:NativeProcess = new NativeProcess();
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = File.userDirectory;
			procInfo.arguments = adbArgs;
			
			proc.addEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit, false, 0, true);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData, false, 0, true);
			proc.start(procInfo);	
		}
		
		protected function onReadAndroidDevicesData(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			androidOutput += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}
		
		protected function onReadAndroidDevicesExit(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData);
			
			proc.closeInput();
			proc.exit();
			
			var data:Array = androidOutput.split("\n");
			androidOutput = null;
			
			var runingIds:Vector.<String> = new Vector.<String>();
			
			if(data.length > 1){
				
				data.shift();
				
				const len:int = data.length;
				var info:Array;
				var dev:RunningDevice;
				
				for(var i:int=0; i<len; i++){
					info = data[i].split(/\s+/g);
					
					const runningId:String = info[0];
					runingIds.push(runningId);
					
					if(info.length >= 2 && runningId.length > 0){
						dev = findDevice(runningId);
						if(dev == null){
							
							dev = new AndroidDevice(adbFile, port, runningId);
							dev.addEventListener(Device.STOPPED_EVENT, deviceStoppedHandler, false, 0, true);
							dev.start();
							
							collection.addItem(dev);
							collection.refresh();
						}
					}
				}
			}
			
			for each(var androidDev:RunningDevice in collection){
				if(androidDev is AndroidDevice && androidDev.simulator == false && runingIds.indexOf(androidDev.id) < 0){
					androidDev.close()
				}
			}
			
			relaunchAdb.restart(true);
		}
		
		//---------------------------------------------------------------------------------------------------------
		//---------------------------------------------------------------------------------------------------------
		
		private function launchIosProcess():void{
			iosOutput = "";
			
			var proc:NativeProcess = new NativeProcess();
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			
			procInfo.executable = envFile;
			procInfo.workingDirectory = File.userDirectory;
			procInfo.arguments = sysprofilerArgs;
			
			proc.addEventListener(NativeProcessExitEvent.EXIT, onUsbDeviceExit);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
			proc.start(procInfo);	
		}
		
		protected function onReadIosDevicesData(ev:ProgressEvent):void{
			iosOutput += ev.currentTarget.standardOutput.readUTFBytes(ev.currentTarget.standardOutput.bytesAvailable);
		}
		
		protected function onUsbDeviceExit(ev:NativeProcessExitEvent):void{
						
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onUsbDeviceExit);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
			
			proc.closeInput();
			proc.exit();
						
			//------------------------------------------------------
			
			iosOutput = iosOutput.replace(/[\n\t]/g, "");
			var plistNodeIndex:int = iosOutput.indexOf("<plist version=\"1.0\">")
			if(plistNodeIndex > -1){
				iosOutput = iosOutput.substr(plistNodeIndex + 21, iosOutput.length - plistNodeIndex - 29);
				
				usbDevicesIdList = new Vector.<String>();
					
				var plist:Plist10 = new Plist10(iosOutput);
				iosOutput = null;
				
				const usbPorts:Array = plist.root._items.object as Array;
				for each (var port:PDict in usbPorts) {
					getDevicesIds(port);
				}
				
				plist.dispose();
				
				for each(var iosDev:RunningDevice in collection){
					if(iosDev is IosDevice && iosDev.simulator == false && usbDevicesIdList.indexOf(iosDev.id) < 0){
						iosDev.close()
					}
				}
				
				loadDevicesId();
				
			}else{
				relaunchIos.restart(true);
			}
		}
		
		private function getDevicesIds(itmList:PDict):void {
			if(itmList.object._items != null) {
				var itemsListArray:Array = itmList.object._items.object as Array;
				for each(var itm:PDict in itemsListArray){
					getDevicesIds(itm);
					var name:String = itm.object._name.toString().toLowerCase();
					if(name == "iphone"){
						usbDevicesIdList.push(itm.object.serial_num);
					}
				}
			}
		}
		
		private function loadDevicesId():void{
			if(usbDevicesIdList.length > 0){
				var id:String = usbDevicesIdList.pop();
				var dev:RunningDevice = findDevice(id) as IosDevice;
				if(dev == null) {
					var devInfo:IosDeviceInfo = new IosDeviceInfo(id);
					devInfo.addEventListener(Event.COMPLETE, realDevicesInfoLoaded, false, 0, true);
					devInfo.load();
				}else{
					loadDevicesId()
				}
			}else{
				realDevicesLoaded();
			}
		}
		
		private function realDevicesInfoLoaded(ev:Event):void{
			var devInfo:IosDeviceInfo = ev.currentTarget as IosDeviceInfo;
			devInfo.removeEventListener(Event.COMPLETE, realDevicesInfoLoaded);
			
			var dev:IosDevice = devInfo.device;	
			dev.addEventListener(Device.STOPPED_EVENT, deviceStoppedHandler, false, 0, true);
			
			collection.addItem(dev);
			collection.refresh();
			
			if(dev.procInfo != null) {
				dev.start();
			}
			
			loadDevicesId()
		}
		
		public function restartDev(dev:Device):void {
			dev.dispose();
			dev.close();
		}
				
		public function findDevice(id:String):RunningDevice{
			for each(var dv:RunningDevice in collection) {
				if(dv.id == id){
					return dv;
				}
			}
			return null;
		}
		
		public function deviceStoppedHandler(ev:Event):void{
			
			var dv:RunningDevice = ev.currentTarget as RunningDevice;
			dv.removeEventListener(Device.STOPPED_EVENT, deviceStoppedHandler);
			
			collection.removeItem(dv);
			collection.refresh();
		}
		
		private function realDevicesLoaded():void{
			
			for each(var sim:IosSimulator in FlexGlobals.topLevelApplication.simulators.collection){
				if(sim.started){
					var dev:IosDevice = findDevice(sim.id) as IosDevice;
					if(dev == null){
						dev = sim.device;	
						dev.start();
						dev.addEventListener(Device.STOPPED_EVENT, deviceStoppedHandler, false, 0, true);
						
						collection.addItem(dev);
						collection.refresh();
					}
				}
			}
			relaunchIos.restart(true);
		}
	}
}