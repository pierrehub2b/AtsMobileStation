package 
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.system.Capabilities;
	
	import mx.collections.ArrayCollection;
	import mx.utils.StringUtil;
	
	import CustomClasses.SimCtlDevice;
	
	import event.SimulatorEvent;
	
	import simulator.IosSimulator;
	import simulator.Simulator;
	
	public class AvailableSimulatorsManager extends EventDispatcher
	{
		public static const SIMULATOR_STATUS_CHANGED:String = "simulatorStatusChanged";
		public static const COLLECTION_CHANGED:String = "collectionChanged";
		
		private const regex:RegExp = /(.*)\(([^\)]*)\).*\[(.*)\](.*)/
		private const jsonPattern:RegExp = /\{[^]*\}/;
		
		private var output:String = "";
		private var arrayInstrument: Array = new Array();
		
		[Bindable]
		public var info:String = "Loading simulators, please wait ...";
			
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		public function AvailableSimulatorsManager()
		{
			if(Capabilities.os.indexOf("Mac") > -1){
				
				var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				var process:NativeProcess = new NativeProcess();
				
				procInfo.executable = new File("/usr/bin/env");
				procInfo.workingDirectory = File.userDirectory;
				
				//process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onSetupSimulatorExit, false, 0, true);
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput, false, 0, true);
				
				procInfo.arguments = new <String>["defaults", "write" ,"com.apple.iphonesimulator", "ShowChrome", "-int", "0"];
				process.start(procInfo);
			}
		}
		
		public function terminate():void{
			//if(process != null && process.running){
			//	process.exit(true);
			//}
		}
		
		protected function onSetupSimulatorExit(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;

			//proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onSetupSimulatorExit);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput);
			
			proc.closeInput();
			proc.exit(true);
			
			AtsMobileStation.simulators.collection = new ArrayCollection();
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			proc = new NativeProcess();
			
			procInfo.executable = new File("/usr/bin/env");
			procInfo.workingDirectory = File.userDirectory;
			
			output = "";
			//proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput, false, 0, true);
			proc.addEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit, false, 0, true);
			
			procInfo.arguments = new <String>["xcrun", "instruments", "-s", "devices"];
			proc.start(procInfo);
		}
				
		/*protected function onOutputErrorShell(ev:ProgressEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			trace(proc.standardError.readUTFBytes(proc.standardError.bytesAvailable));
		}*/
		
		protected function onProcessOutput(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			output += StringUtil.trim(proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable));
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
		
		protected function onSimCtlExist(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			//proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist);
			
			proc.closeInput();
			proc.exit(true);
						
			var obj:Object;
			if(output.length > 0) {
				var data:Array = jsonPattern.exec(output);
				if(data != null && data.length > 0){
					obj = JSON.parse(data[0]);
					var devices:Object = obj["devices"];
					var simctl:Array = new Array();
					
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
						if(line.toLocaleLowerCase().indexOf("iphone") > -1) {
							data = regex.exec(line);
							if(data != null){
								var currentElement:SimCtlDevice = getByUdid(simctl, data[3]);
								if((currentElement != null && currentElement.getIsAvailable())) {
									var isRunning:Boolean = currentElement != null ? currentElement.getState() == "Booted" : false;
									if(isRunning) {
										AtsMobileStation.startedIosSimulator.push(data[3]);
									}
									var sim:IosSimulator = new IosSimulator(data[3], data[1], data[2], isRunning, true);
									sim.addEventListener(Simulator.STATUS_CHANGED, simulatorStatusChanged, false, 0, true);
									AtsMobileStation.simulators.collection.addItem(sim);
								}
							}
						}
					}
				}
				
				if(AtsMobileStation.simulators.collection.length == 0){
					info = "No simulators found !\n(Xcode may not be installed on this station !)"
				}else{
					info = "";
				}
			}
		}
		
		public function updateSimulatorInList(id:String, started:Boolean):void {
			var index:int = 0;
			for each(var elem: IosSimulator in collection) {
				if(elem.id == id) {
					elem.phase = started ? Simulator.RUN : Simulator.OFF; 					
					collection.setItemAt(elem,index);
					break;
				}
				index++;
			}
			this.collection.refresh();
		}
		
		protected function onInstrumentsExit(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			//proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit);
			
			proc.closeInput();
			proc.exit(true);
			
			arrayInstrument = output.split("\n");
			
			output = ""
				
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			proc = new NativeProcess();
			
			procInfo.executable = new File("/usr/bin/env");
			procInfo.workingDirectory = File.userDirectory;
			
			//proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput, false, 0, true);
			proc.addEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist, false, 0, true);
			
			procInfo.arguments = new <String>["xcrun", "simctl", "list", "devices", "-j"];
			proc.start(procInfo);
		}
		
		protected function simulatorStatusChanged(ev:Event):void{
			var sim:IosSimulator = ev.currentTarget as IosSimulator;
			dispatchEvent(new SimulatorEvent(SIMULATOR_STATUS_CHANGED, sim));
		}
	}
}