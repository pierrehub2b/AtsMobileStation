package 
{
	import CustomClasses.SimCtlDevice;
	
	import device.AndroidDevice;
	import device.Device;
	import device.IosDevice;
	
	import event.SimulatorEvent;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.system.Capabilities;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.utils.StringUtil;
	
	import simulator.IosSimulator;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	
	public class RunningDevicesManager
	{
		
		//ios Proc info
		protected var iosProcInfo:NativeProcessStartupInfo;
		public var iosProcess:NativeProcess;
		
		//android Proc info
		protected var adbProcInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		public var adbProcess:NativeProcess = new NativeProcess();
		
		private const iosDevicePattern:RegExp = /(.*)\(([^\)]*)\).*\[(.*)\](.*)/
		private const jsonPattern:RegExp = /\{[^]*\}/;
		
		private var adbFile:File;
		private var errorStack:String = "";
		private var output:String = "";
		
		private var androidTimer:Timer = new Timer(5000);
		private var iosTimer:Timer = new Timer(5000);
		private var port:String = "8080";
		
		private var arrayInstrument: Array = new Array();
		
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		private var ipSort:Sort = new Sort([new SortField("ip")]);
		
		public static var devTeamId:String = "";
		
		public function RunningDevicesManager(port:String)
		{
			this.port = port;
			this.collection.sort = ipSort;
			
			this.androidTimer.addEventListener(TimerEvent.TIMER, androidTimerComplete, false, 0, true);
			this.iosTimer.addEventListener(TimerEvent.TIMER, iosTimerComplete, false, 0, true);
			
			var adbPath:String = "assets/tools/android/adb";
			if(Capabilities.os.indexOf("Mac") > -1){
				
				//-----------------------------------------------------------------------------
				// IOS
				//-----------------------------------------------------------------------------
				
				iosProcInfo = new NativeProcessStartupInfo();
				iosProcess = new NativeProcess();
				
				iosProcInfo.executable = new File("/usr/bin/env");
				iosProcInfo.workingDirectory = File.userDirectory;
				
				this.iosProcInfo.arguments = new <String>["xcrun", "instruments", "-s", "devices"];
				launchIosProcess();
					
				//-----------------------------------------------------------------------------
				// ANDROID
				//-----------------------------------------------------------------------------
				
				var chmod:File = new File("/bin/chmod");
				this.adbFile = File.applicationDirectory.resolvePath(adbPath);
				this.adbProcInfo.executable = chmod;			
				this.adbProcInfo.workingDirectory = adbFile.parent;
				this.adbProcInfo.arguments = new <String>["+x", "adb"];
				this.adbProcess.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
				this.adbProcess.start(this.adbProcInfo);
				
			}else{
				this.adbFile = File.applicationDirectory.resolvePath(adbPath + ".exe");
				initAdbProcess();
			}
		}
		
		private function initAdbProcess():void{
			adbProcess = new NativeProcess();
			adbProcInfo.executable = adbFile;			
			adbProcInfo.workingDirectory = adbFile.parent;
			adbProcInfo.arguments = new <String>["devices"];
			
			launchAdbProcess();
		}
		
		protected function onChmodExit(event:NativeProcessExitEvent):void
		{
			adbProcess.removeEventListener(NativeProcessExitEvent.EXIT, onChmodExit);
			initAdbProcess();
		}	
		
		public function restartDev(dev:Device):void {
			var tmpCollection:ArrayCollection = new ArrayCollection();
			for each(var dv:Device in this.collection) {
				if(dv.id != dev.id) {
					tmpCollection.addItem(dv);
				}
			}
			dev.dispose();
			dev.close();
			this.collection = tmpCollection;
			this.collection.refresh();
		}
		
		public function getByUdid(array:Array, search:String):SimCtlDevice {
			var i:int = 0;
			for each(var simCtl:SimCtlDevice in array)
			{
				if(simCtl.getUdid() == search) {
					return simCtl;
				}
				i++;
			}
			return null;
		}
		
		public function terminate():void{
			var dv:Device;
			for each(dv in collection){
				if(dv.isSimulator) {
					dv.dispose();
				}
			}
			
			iosProcess.exit(true);
			
			iosProcInfo.arguments = new <String>["kill-server"];
			iosProcess.start(iosProcInfo);
		}
		
		private function launchAdbProcess():void{
			output = "";
			errorStack = "";
			
			try{
				//process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				adbProcess.addEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit, false, 0, true);
				adbProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData, false, 0, true);
				adbProcess.start(adbProcInfo);
			}catch(err:Error){}
		}
		
		private function launchIosProcess():void{
			output = "";
			errorStack = "";
			this.iosProcInfo.arguments = new <String>["xcrun", "instruments", "-s", "devices"];
			
			try{
				//process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				iosProcess.addEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit, false, 0, true);
				iosProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData, false, 0, true);
				iosProcess.start(iosProcInfo);
			}catch(err:Error){}
		}
		
		private function iosTimerComplete(ev:TimerEvent):void{
			launchIosProcess();
		}
		
		private function androidTimerComplete(ev:TimerEvent):void{
			launchAdbProcess();
		}
		
		protected function onReadAndroidDevicesData(event:ProgressEvent):void{
			output += StringUtil.trim(adbProcess.standardOutput.readUTFBytes(adbProcess.standardOutput.bytesAvailable));
		}
		
		protected function onReadIosDevicesData(event:ProgressEvent):void{
			output += StringUtil.trim(iosProcess.standardOutput.readUTFBytes(iosProcess.standardOutput.bytesAvailable));
		}
		
		protected function onReadAndroidDevicesExit(event:NativeProcessExitEvent):void
		{
			//process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			adbProcess.removeEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit);
			adbProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData);
			
			var dv:Device;
			for each(dv in collection){
				dv.connected = false;
			}
			
			var data:Array = output.split("\n");
			if(data.length > 1){
				
				var len:int = data.length;
				var info:Array;
				var dev:Device;
				
				for(var i:int=1; i<len; i++){
					info = data[i].split(/\s+/g);
					if(info.length >= 2){
						dev = findDevice(info[0]);
						if(dev == null){
							dev = new AndroidDevice(adbFile, port, info[0], info[1]);
							dev.addEventListener("deviceStopped", deviceStoppedHandler, false, 0, true);
							collection.addItem(dev);
							collection.refresh();
						}else{
							dev.connected = true;
						}
					}
				}
			}
			
			for each(dv in collection){
				if(!dv.connected && dv.manufacturer != "Apple"){
					dv.dispose();
					collection.removeItem(dv);
					collection.refresh();
				}
			}
			
			androidTimer.start();
		}
		
		protected function simulatorStatusChanged(ev:Event):void{
			var sim:IosSimulator = ev.currentTarget as IosSimulator;
			sim.dispatchEvent(new SimulatorEvent(AvailableSimulatorsManager.SIMULATOR_STATUS_CHANGED, sim));
		}
		
		protected function onInstrumentsExit(event:NativeProcessExitEvent):void
		{
			//process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			iosProcess.removeEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit);
			iosProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
			arrayInstrument = output.split("\n");
			
			var dev:Device;
			var dv:Device;
			for each(dv in collection){
				dv.connected = false;
			}
			arrayInstrument.removeAt(0)
			var containsPhysicalDevice:Boolean = false;
			
			for each(var line:String in arrayInstrument){
				
				var isPhysicalDevice: Boolean = line.indexOf("(Simulator)") == -1;
				var data:Array = iosDevicePattern.exec(line);
				
				if(isPhysicalDevice) {
					containsPhysicalDevice = true;
				}
				
				if(isPhysicalDevice) {
					if(data != null){
						dev = findDevice(data[3]) as IosDevice;
						var isRedifined:Boolean = false;
						if(dev != null && dev.isCrashed) {
							isRedifined = true;
							dev.dispose();
							dev.close();
							collection.removeItem(dev);
							collection.refresh();
						}
						if(dev == null || isRedifined) {
							var sim:IosSimulator = new IosSimulator(data[3], data[1], data[2], true, !isPhysicalDevice);
							dev = sim.device;								
							collection.addItem(dev);
							collection.refresh();
						}else {
							dev.connected = true;
						}
					}
				}
			}
			
			if(!containsPhysicalDevice) {
				var tmpCollection:ArrayCollection = collection;
				for each(var d:Device in tmpCollection) {
					if(!d.isSimulator) {
						d.dispose();
						d.close();
						collection.removeItem(d);
						collection.refresh();
					}
				}
			}
			
			for each(dv in collection){
				if(!dv.connected && dv.isSimulator){
					AtsMobileStation.devices.restartDev(dev);
				}
			}
			
			iosTimer.start();	
		}
		
		public function findDevice(id:String):Device{
			for each(var dv:Device in collection) {
				if(dv.id == id){
					if(dv.manufacturer != "Apple") {
						return dv as AndroidDevice;
					} else {
						return dv as IosDevice;
					}
				}
			}
			return null;
		}
		
		private function deviceStoppedHandler(ev:Event):void{
			var dv:Device = ev.currentTarget as Device;
			dv.removeEventListener("deviceStopped", deviceStoppedHandler);
			dv.dispose();
			collection.removeItem(dv);
		}
	}
}