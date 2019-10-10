package 
{
	import com.greensock.TweenMax;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.system.Capabilities;
	
	import mx.collections.ArrayCollection;
	import mx.core.FlexGlobals;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	
	import CustomClasses.SimCtlDevice;
	
	import device.AndroidDevice;
	import device.Device;
	import device.IosDevice;
	
	import event.SimulatorEvent;
	
	import simulator.IosSimulator;
	
	public class RunningDevicesManager
	{
		private const adbPath:String = "assets/tools/android/adb";
		private const iosDevicePattern:RegExp = /(.*)\(([^\)]*)\).*\[(.*)\](.*)/
		private const jsonPattern:RegExp = /\{[^]*\}/;
		
		private const relaunchDelay:int = 10;
		
		private var adbFile:File;
		private var errorStack:String = "";
		private var androidOutput:String = "";
		private var iosOutput:String = "";
		
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
			
			if(Capabilities.os.indexOf("Mac") > -1){
				
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
				proc.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
				proc.start(procInfo);
				
			}else{
				this.adbFile = File.applicationDirectory.resolvePath(adbPath + ".exe");
				launchAdbProcess();
			}
		}
		
		protected function onChmodExit(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onChmodExit);
			proc.closeInput();
			proc.exit(true);
			
			launchAdbProcess();
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
		
		public function terminateSimulator(id:String):void{
			var index:int = 0;
			for each(var d:Device in collection) {
				if(id == d.id) {
					(d as IosDevice).dispose();
					d.close();
					collection.removeItemAt(index);
					collection.refresh();
					break;
				}
				index++;
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
		
		public function terminate():void{
			var dv:Device;
			for each(dv in collection){
				if(dv.isSimulator) {
					dv.dispose();
				}
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
			procInfo.arguments = new <String>["devices"];
			
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
			
			var dv:Device;
			for each(dv in collection){
				dv.connected = false;
			}
			
			var data:Array = androidOutput.split("\n");
			if(data.length > 1){
				
				var len:int = data.length;
				var info:Array;
				var dev:Device;
				
				for(var i:int=1; i<len; i++){
					info = data[i].split(/\s+/g);
					if(info.length >= 2 && info[0].length > 0){
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
			procInfo.arguments = new <String>["xcrun", "instruments", "-s", "devices"];
			
			proc.addEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit, false, 0, true);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData, false, 0, true);
			
			try{
				proc.start(procInfo);	
			}catch(err:Error){
				trace("instruments proc start error -> " + err.message);
				proc.removeEventListener(NativeProcessExitEvent.EXIT, onSimCtlExit);
				proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
				proc.closeInput();
				proc.exit(true);
				
				TweenMax.delayedCall(relaunchDelay, launchIosProcess);
			}
		}
		
		protected function onReadIosDevicesData(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			iosOutput += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}
		
		protected function simulatorStatusChanged(ev:Event):void{
			var sim:IosSimulator = ev.currentTarget as IosSimulator;
			sim.dispatchEvent(new SimulatorEvent(AvailableSimulatorsManager.SIMULATOR_STATUS_CHANGED, sim));
		}
		
		protected function onInstrumentsExit(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
			
			proc.closeInput();
			proc.exit(true);
			
			arrayInstrument = iosOutput.split("\n");
			iosOutput = "";
			
			proc = new NativeProcess();
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			
			procInfo.executable = new File("/usr/bin/env");
			procInfo.workingDirectory = File.userDirectory;
			procInfo.arguments = new <String>["xcrun", "simctl", "list", "devices", "-j"];
			
			proc.addEventListener(NativeProcessExitEvent.EXIT, onSimCtlExit, false, 0, true);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData, false, 0, true);
			
			try{
				proc.start(procInfo);	
			}catch(err:Error){
				trace("simctl proc start error -> " + err.message);
				proc.removeEventListener(NativeProcessExitEvent.EXIT, onSimCtlExit);
				proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
				proc.closeInput();
				proc.exit(true);
				
				TweenMax.delayedCall(relaunchDelay, launchIosProcess);
			}

		}
		
		private function onSimCtlExit(ev: NativeProcessExitEvent): void 
		{	
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onSimCtlExit);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
			
			proc.closeInput();
			proc.exit(true);
			
			var dev:Device;
			var dv:Device;
			var simCtl:Array = new Array();
			
			for each(dv in collection){
				dv.connected = false;
			}
			var data:Array = jsonPattern.exec(iosOutput);
			if(data == null) {
				return;
			}
			
			var jsonSimCtlObject:Object = null;
			try{
				jsonSimCtlObject = JSON.parse(data[0]);
			}catch(error:Error){
				TweenMax.delayedCall(relaunchDelay, launchIosProcess);
				return;
			}
			
			var JSONDevicesObject:Object = jsonSimCtlObject["devices"];
			for each(var runtime:Object in JSONDevicesObject) {
				for each(var device:Object in runtime) {
					var availabilityError:String = ""
					if(!device["isAvailable"]) {
						availabilityError = device["availabilityError"];
					}
					simCtl.push(new SimCtlDevice(availabilityError,device["isAvailable"] ,device["name"] ,device["state"] ,device["udid"]));
				}
				simCtl.push(new SimCtlDevice(availabilityError,device["isAvailable"] ,device["name"] ,device["state"] ,device["udid"]));
			}
			
			arrayInstrument.removeAt(0)
			var containsPhysicalDevice:Boolean = false;
			
			for each(var line:String in arrayInstrument){
				
				if(line.indexOf("(null)") == -1){
					
					var isPhysicalDevice: Boolean = line.indexOf("(Simulator)") == -1;
					data = iosDevicePattern.exec(line);
					
					if(isPhysicalDevice) {
						containsPhysicalDevice = true;
					}
					
					if(data != null && (line.toLocaleLowerCase().indexOf("iphone") > -1 || isPhysicalDevice)) {
						var currentElement:SimCtlDevice = getByUdid(simCtl, data[3]);
						if((currentElement != null && currentElement.getIsAvailable()) || isPhysicalDevice) {
							var isRunning:Boolean = currentElement != null ? currentElement.getState() == "Booted" : isPhysicalDevice;
							if(isRunning) {
								dev = findDevice(data[3]) as IosDevice;
								var isRedifined:Boolean = false;
								
								if(dev != null && dev.isCrashed) {
									isRedifined = true;
									dev.dispose();
									dev.close();
									collection.removeItem(dev);
									collection.refresh();
								}
								
								/*if(AtsMobileStation.startedIosSimulator.indexOf(data[3],0) == -1) {
								AtsMobileStation.startedIosSimulator.push(data[3]);
								}*/
								
								if(dev == null || isRedifined) {
									var sim:IosSimulator = new IosSimulator(data[3], data[1], data[2], true, !isPhysicalDevice);
									dev = sim.device;	
									if(!isPhysicalDevice) {
										FlexGlobals.topLevelApplication.updateSimulatorInList(data[3], true);
										dev.addEventListener("deviceStopped", deviceStoppedHandler, false, 0, true);
									}
									collection.addItem(dev);
									collection.refresh();
								}else if(dev != null) {
									dev.connected = true;
								}
								/*}else if(AtsMobileStation.startedIosSimulator.indexOf(data[3],0) > -1) {
								AtsMobileStation.startedIosSimulator.removeAt(AtsMobileStation.startedIosSimulator.indexOf(data[3],0));
								AtsMobileStation.simulators.updateSimulatorInList(data[3], false);
								dev = findDevice(data[3]);
								if(dev != null) {
								(dev as IosDevice).dispose();
								dev.close();
								collection.removeItem(dev);
								collection.refresh();
								}*/
							}
						}
					}
				}
			}
			
			if(!containsPhysicalDevice) {
				var tmpCollection:ArrayCollection = new ArrayCollection(collection.source);
				for each(var d:Device in tmpCollection) {
					if(d is IosDevice && !d.isSimulator) {
						d.dispose();
						d.close();
						collection.removeItem(d);
						collection.refresh();
					}
				}
			}
			
			for each(dv in collection){
				if(!dv.connected && dv.isSimulator){
					FlexGlobals.topLevelApplication.restartDevice(dev);
				}
			}
			
			TweenMax.delayedCall(relaunchDelay, launchIosProcess);
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
		
		public function deviceStoppedHandler(ev:Event):void{
			var dv:Device = ev.currentTarget as Device;
			dv.removeEventListener("deviceStopped", deviceStoppedHandler);
			dv.dispose();
			collection.removeItem(dv);
		}
	}
}