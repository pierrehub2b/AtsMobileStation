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
		
		private var regex:RegExp = /iPhone(.*)\(([^\)]*)\).*\[(.*)\](.*)/
			
		protected var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		protected var process:NativeProcess = new NativeProcess();
		
		protected var procInfoState:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		protected var processState:NativeProcess = new NativeProcess();
		
		private var output:String = "";
		private var arrayInstrument: Array = new Array();
		
		[Bindable]
		public var info:String = "Loading simulators, please wait ...";
			
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		public function AvailableSimulatorsManager()
		{
			if(Capabilities.os.indexOf("Mac") > -1){
				procInfo.executable = new File("/usr/bin/env");
				procInfo.workingDirectory = File.userDirectory;
				
				process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit, false, 0, true);
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onInstrumentsOutput, false, 0, true);
				
				procInfo.arguments = new <String>["xcrun", "instruments", "-s", "devices"];
				process.start(procInfo);
			}
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			trace(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
		}
		
		protected function onInstrumentsOutput(event:ProgressEvent):void{
			output += StringUtil.trim(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function getByUdid(array:Array, search:String):SimCtlDevice {
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
		
		protected function onSimCtlExist(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onInstrumentsOutput);
			
			var obj:Object=JSON.parse(output);
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
			
			for each(var line:String in arrayInstrument){
				if(line.indexOf("iPhone") == 0){
					var data:Array = regex.exec(line);
					if(data != null){
						// filter for getting the right element in list
						var currentElement:SimCtlDevice = getByUdid(simctl, data[3]);
						if(currentElement != null && currentElement.getIsAvailable()) {
							var sim:IosSimulator = new IosSimulator(data[3], "iPhone" + data[1], data[2], currentElement.getState() == "Booted");
							sim.addEventListener(Simulator.STATUS_CHANGED, simulatorStatusChanged, false, 0, true);
							collection.addItem(sim);
							if(sim.phase == Simulator.RUN) {
								dispatchEvent(new SimulatorEvent(SIMULATOR_STATUS_CHANGED, sim));
							}
						}
					}
				}
			}
			
			if(collection.length == 0){
				info = "No simulators found !\n(Xcode may not be installed on this station !)"
			}else{
				info = "";
			}
		}
		
		protected function onInstrumentsExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit);
			arrayInstrument = output.split("\n");
			output = ""
			//now retrieving the list of simulators with status	
			process.addEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist, false, 0, true);
			procInfo.arguments = new <String>["xcrun", "simctl", "list", "devices", "--j"];
			process.start(procInfo);
		}
		
		protected function simulatorStatusChanged(ev:Event):void{
			var sim:IosSimulator = ev.currentTarget as IosSimulator;
			dispatchEvent(new SimulatorEvent(SIMULATOR_STATUS_CHANGED, sim));
		}
	}
}