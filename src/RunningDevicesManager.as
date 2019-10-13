package 
{
	import com.greensock.TweenMax;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.system.System;
	
	import mx.collections.ArrayCollection;
	import mx.core.FlexGlobals;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	
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
		private const simCtlArgs:Vector.<String> = new <String>["xcrun", "simctl", "list", "devices", "-j"];
		private const adbArgs:Vector.<String> = new <String>["devices"];
		
		private const mobileDevice:File = File.applicationDirectory.resolvePath("assets/tools/ios/mobiledevice");
		
		private const systemProfiler:File = new File("/usr/sbin/system_profiler");
		
		private const adbPath:String = "assets/tools/android/adb";
		private const iosDevicePattern:RegExp = /(.*)\(([^\)]*)\).*\[(.*)\](.*)/
		private const jsonPattern:RegExp = /\{[^]*\}/;
		
		private const relaunchDelay:int = 3;
		
		private var adbFile:File;
		private var errorStack:String = "";
		private var androidOutput:String = "";
		private var iosOutput:String = "";
		
		private var port:String = "8080";
		
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		private var ipSort:Sort = new Sort([new SortField("ip")]);
		
		public static var devTeamId:String = "";
		
		private var usbDevicesIdList:Vector.<String>;
		
		public function RunningDevicesManager(port:String, isMacOs:Boolean)
		{
			this.port = port;
			this.collection.sort = ipSort;
			
			if(isMacOs){
				
				//-----------------------------------------------------------------------------
				// IOS
				//-----------------------------------------------------------------------------
				
				launchIosProcess();
				
				//-----------------------------------------------------------------------------
				// ANDROID
				//-----------------------------------------------------------------------------
				
				this.adbFile = File.applicationDirectory.resolvePath(adbPath);
				
				var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				procInfo.executable = new File("/bin/chmod");			
				procInfo.workingDirectory = adbFile.parent;
				procInfo.arguments = new <String>["+x", "adb"];
				
				var proc:NativeProcess = new NativeProcess();
				proc.addEventListener(NativeProcessExitEvent.EXIT, onChmodAdbExit, false, 0, true);
				proc.start(procInfo);
				
			}else{
				this.adbFile = File.applicationDirectory.resolvePath(adbPath + ".exe");
				launchAdbProcess();
			}
		}
		
		protected function onChmodAdbExit(ev:NativeProcessExitEvent):void
		{
			const mobileDevice:File = File.applicationDirectory.resolvePath("assets/tools/ios/mobiledevice");
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = new File("/bin/chmod");			
			procInfo.workingDirectory = mobileDevice.parent;
			procInfo.arguments = new <String>["+x", "mobiledevice"];
			
			var proc:NativeProcess = new NativeProcess();
			proc.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
			proc.start(procInfo);
		}
		
		protected function onChmodExit(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onChmodExit);
			proc.closeInput();
			proc.exit(true);
			
			launchAdbProcess();
		}	
		
		public function terminate():void{
			var dv:RunningDevice;
			for each(dv in collection){
				dv.close();
			}
			TweenMax.killDelayedCallsTo(launchAdbProcess);
			TweenMax.killDelayedCallsTo(launchIosProcess);
		}
		
		private function launchAdbProcess():void{
			
			androidOutput = "";
			errorStack = "";
			
			var proc:NativeProcess = new NativeProcess();
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = adbFile.parent;
			procInfo.arguments = adbArgs;
			
			proc.addEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit, false, 0, true);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData, false, 0, true);
			
			try{
				proc.start(procInfo);	
			}catch(err:Error){
				trace("adb proc start error -> " + err.message);
				proc.removeEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit);
				proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData);
				proc.closeInput();
				proc.exit(true);
				
				TweenMax.delayedCall(relaunchDelay, launchAdbProcess);
			}
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
			proc.exit(true);
			
			var data:Array = androidOutput.split("\n");
			var runingIds:Vector.<String> = new Vector.<String>();
			
			if(data.length > 1){
				
				var len:int = data.length;
				var info:Array;
				var dev:RunningDevice;
				
				for(var i:int=1; i<len; i++){
					info = data[i].split(/\s+/g);
					
					var runningId:String = info[0];
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
			
			TweenMax.delayedCall(relaunchDelay, launchAdbProcess);
		}
		
		//---------------------------------------------------------------------------------------------------------
		//---------------------------------------------------------------------------------------------------------
		
		private function launchIosProcess():void{
			iosOutput = "";
			errorStack = "";
			
			var proc:NativeProcess = new NativeProcess();
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			
			procInfo.executable = new File("/usr/bin/env");
			procInfo.workingDirectory = File.userDirectory;
			procInfo.arguments = new <String>["system_profiler", "SPUSBDataType", "-xml"];
			
			proc.addEventListener(NativeProcessExitEvent.EXIT, onUsbDeviceExit, false, 0, true);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData, false, 0, true);
			
			try{
				proc.start(procInfo);	
			}catch(err:Error){
				trace("mobile device proc start error -> " + err.message);
				proc.removeEventListener(NativeProcessExitEvent.EXIT, onUsbDeviceExit);
				proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
				proc.closeInput();
				proc.exit(true);
				
				TweenMax.delayedCall(relaunchDelay, launchIosProcess);
			}
		}
		
		protected function onUsbDeviceExit(ev:NativeProcessExitEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onUsbDeviceExit);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
			
			proc.closeInput();
			proc.exit(true);
			
			usbDevicesIdList = new Vector.<String>();
			
			//------------------------------------------------------
			
			try{
				var data:XML = new XML(iosOutput);
				var plist:Plist10 = new Plist10();
				
				plist.parse(data.children()[0]);
				
				var itemsList:Array = plist.root._items.object[0].object._items.object as Array;
				for each(var itm:PDict in itemsList){
					if(itm.object._name == "iPhone"){
						usbDevicesIdList.push(itm.object.serial_num);
					}
				}
				System.disposeXML(data);
			}catch(error:Error){}
			
			//------------------------------------------------------
			
			for each(var iosDev:RunningDevice in collection){
				if(iosDev is IosDevice && iosDev.simulator == false && usbDevicesIdList.indexOf(iosDev.id) < 0){
					iosDev.close()
				}
			}
			
			loadDevicesId();
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
			
			dev.start();
			
			loadDevicesId()
		}
		
		protected function onReadIosDevicesData(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			iosOutput += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
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
			
			TweenMax.delayedCall(relaunchDelay, launchIosProcess);
		}
	}
}