package 
{
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
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	
	import CustomClasses.SimCtlDevice;
	
	import device.AndroidDevice;
	import device.Device;
	
	import event.SimulatorEvent;
	
	import simulator.IosSimulator;
	import simulator.Simulator;
	
	public class RunningDevicesManager
	{
		protected var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		protected var process:NativeProcess = new NativeProcess();
	
		private var regex:RegExp = /(.*)\(([^\)]*)\).*\[(.*)\](.*)/
			
		private var adbFile:File;
		private var errorStack:String = "";
		private var output:String = "";
		
		private var timer:Timer = new Timer(3000);
		private var port:String = "8080";
		
		private var arrayInstrument: Array = new Array();
		
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		private var ipSort:Sort = new Sort([new SortField("ip")]);
		
		public function RunningDevicesManager(port:String)
		{
			this.port = port;
			this.collection.sort = ipSort;
			
			var adbPath:String = "assets/tools/android/adb";
			if(Capabilities.os.indexOf("Mac") > -1){
				startIosProcess();				
			}else{
				this.adbFile = File.applicationDirectory.resolvePath(adbPath + ".exe");
				startAdbProcess(); 
			}
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
		
		public function simulatorChanged(sim:IosSimulator):void{
			if(sim.phase == Simulator.RUN){
				collection.addItem(sim.device);
			}else{
				var dv:Device = findDevice(sim.id)
				if(dv != null){
					collection.removeItem(dv);
					dv.dispose();
				}
			}
			collection.refresh()
		}
		
		private function startAdbProcess():void{
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = adbFile.parent;
			procInfo.arguments = new <String>["devices"];
			
			timer.addEventListener(TimerEvent.TIMER, devicesTimerComplete, false, 0, true);
			
			launchProcess();
		}
		
		protected function startIosProcess():void {
			procInfo.executable = new File("/usr/bin/env");
			procInfo.workingDirectory = File.userDirectory;
			this.procInfo.arguments = new <String>["xcrun", "instruments", "-s", "devices"];
			
			timer.addEventListener(TimerEvent.TIMER, devicesTimerComplete, false, 0, true);
			
			launchIosProcess();
		}
		
		public function terminate():void{
			var dv:Device;
			for each(dv in collection){
				dv.dispose();
			}
			
			process.exit(true);
			
			procInfo.arguments = new <String>["kill-server"];
			process.start(procInfo);
		}
		
		private function launchProcess():void{
			output = "";
			errorStack = "";
			
			try{
				//process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit, false, 0, true);
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData, false, 0, true);
				process.start(procInfo);
			}catch(err:Error){}
		}
		
		private function launchIosProcess():void{
			output = "";
			errorStack = "";
			this.procInfo.arguments = new <String>["xcrun", "instruments", "-s", "devices"];
			
			try{
				//process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit, false, 0, true);
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData, false, 0, true);
				process.start(procInfo);
			}catch(err:Error){}
		}
		
		private function devicesTimerComplete(ev:TimerEvent):void{
			if(Capabilities.os.indexOf("Mac") > -1){
				launchIosProcess();
				
			} else {
				launchProcess();
			}
		}
		
		protected function onReadAndroidDevicesData(event:ProgressEvent):void{
			output += StringUtil.trim(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onReadAndroidDevicesExit(event:NativeProcessExitEvent):void
		{
			//process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData);
			
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
				if(!dv.connected){
					dv.dispose();
					collection.removeItem(dv);
					collection.refresh();
				}
			}
			
			timer.start();
		}
		
		protected function onSimCtlExist(event:NativeProcessExitEvent):void {
			//process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData);
			
			var dv:Device;
			for each(dv in collection){
				dv.connected = false;
			}
			var obj:Object;
			var dev:Device;
			var devices:Object;
			var simctl:Array = new Array();
			
			try {	
				obj = JSON.parse(output);
				devices = obj["devices"];
				for each(var runtime:Object in devices) {
					for each(var device:Object in runtime) {
						var availabilityError:String = ""
						if(!device["isAvailable"]) {
							availabilityError = device["availabilityError"];
						}
						simctl.push(new SimCtlDevice(availabilityError,device["isAvailable"] ,device["name"] ,device["state"] ,device["udid"]));
					}
				}
				
				arrayInstrument.removeAt(0)
				for each(var line:String in arrayInstrument){
					//var isPhysicalDevice: Boolean = line.indexOf("(Simulator)") == -1;
					var isPhysicalDevice: Boolean = false;
					if(line.indexOf("iPhone") == 0 || isPhysicalDevice) {
						var data:Array = regex.exec(line);
						if(data != null){
							var currentElement:SimCtlDevice = getByUdid(simctl, data[3]);
							if((currentElement != null && currentElement.getIsAvailable()) || isPhysicalDevice) {
								var isRunning:Boolean = currentElement != null ? currentElement.getState() == "Booted" : isPhysicalDevice;
								if(isRunning) {
									dev = findDevice(data[3]);
									
									if(dev != null && dev.isCrashed) {
										dev.dispose();
										dev.close();
										collection.removeItem(dev);
										dev = null;
									}

									if(dev == null){
										var sim:IosSimulator = new IosSimulator(data[3], data[1], data[2], isRunning, !isPhysicalDevice);
										AtsMobileStation.simulators.updateSimulatorInList(sim);
										dev = sim.device;
										dev.addEventListener("deviceStopped", deviceStoppedHandler, false, 0, true);
										collection.addItem(dev);
										collection.refresh();
									}else{
										dev.connected = true;
									}
								}
							}
						}
					}
				}
				
				for each(dv in collection){
					if(!dv.connected){
						dv.dispose();
						collection.removeItem(dv);
						collection.refresh();
					}
				}
				
				
				timer.start();
				
			} catch(err:Error){
				trace(err);
				timer.start();
			} 
			
		}
		
		protected function simulatorStatusChanged(ev:Event):void{
			var sim:IosSimulator = ev.currentTarget as IosSimulator;
			sim.dispatchEvent(new SimulatorEvent(AvailableSimulatorsManager.SIMULATOR_STATUS_CHANGED, sim));
		}
		
		protected function onInstrumentsExit(event:NativeProcessExitEvent):void
		{
			//process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit);
			arrayInstrument = output.split("\n");
			output = ""
			//now retrieving the list of simulators with status	
			process.addEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist, false, 0, true);
			procInfo.arguments = new <String>["xcrun", "simctl", "list", "devices", "--j"];
			process.start(procInfo);
		}
		
		private function findDevice(id:String):Device{
			for each(var dv:Device in collection){
				if(dv.id == id){
					return dv;
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