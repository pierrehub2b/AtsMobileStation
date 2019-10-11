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
		private const iosVersionReplacmentPattern:RegExp = /-/g; 
		
		private var output:String = "";
		
		[Bindable]
		public var info:String = "";
			
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		public function AvailableSimulatorsManager()
		{
			if(Capabilities.os.indexOf("Mac") > -1){
				
				info = "Loading simulators, please wait ...";
				
				var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				var process:NativeProcess = new NativeProcess();
				
				procInfo.executable = new File("/usr/bin/env");
				procInfo.workingDirectory = File.userDirectory;
				
				process.addEventListener(NativeProcessExitEvent.EXIT, onSetupSimulatorExit, false, 0, true);
				
				procInfo.arguments = new <String>["defaults", "write" ,"com.apple.iphonesimulator", "ShowChrome", "-int", "0"];
				process.start(procInfo);
			}else{
				info = "Android simulators are not yet implemented ...";
			}
		}
		
		protected function onSetupSimulatorExit(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onSetupSimulatorExit);
			
			proc.closeInput();
			proc.exit(true);
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			proc = new NativeProcess();
			
			procInfo.executable = new File("/usr/bin/env");
			procInfo.workingDirectory = File.userDirectory;
			
			output = "";
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput, false, 0, true);
			proc.addEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist, false, 0, true);
			
			procInfo.arguments = new <String>["xcrun", "simctl", "list", "devices", "-j"];
			proc.start(procInfo);
		}
		
		protected function onProcessOutput(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			output += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
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
					
					for (var runtime:Object in devices) {
						var iosVersion:String = runtime.toString().split(".")[runtime.toString().split(".").length-1].replace(iosVersionReplacmentPattern, ".");
						for (var d:Object in devices[runtime]) {
							var device:Object = devices[runtime][d];
							if(device["name"].indexOf("iPhone") == 0 && device["isAvailable"] && iosVersion.indexOf("iOS") > -1) {
								var sim:IosSimulator = new IosSimulator(device["udid"], device["name"] , iosVersion.replace("iOS.",""), device["state"] == "Booted", true);
								sim.addEventListener(Simulator.STATUS_CHANGED, simulatorStatusChanged, false, 0, true);
								collection.addItem(sim);
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
		}
		
		public function updateSimulatorInList(id:String, started:Boolean):void {
			for each(var elem: IosSimulator in collection) {
				if(elem.id == id) {
					elem.phase = started ? Simulator.RUN : Simulator.OFF; 					
					break;
				}
			}
		}
		
		protected function simulatorStatusChanged(ev:Event):void{
			var sim:IosSimulator = ev.currentTarget as IosSimulator;
			dispatchEvent(new SimulatorEvent(SIMULATOR_STATUS_CHANGED, sim));
		}
	}
}