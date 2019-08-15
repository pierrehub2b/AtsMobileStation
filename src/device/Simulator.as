package device
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	public class Simulator
	{
		
		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");

		public static const OFF:String = "off";
		public static const WAIT:String = "wait";
		public static const RUN:String = "run";
		
		public var uid:String;
		
		[Bindable]
		public var name:String;
		
		[Bindable]
		public var os:String;
		
		[Bindable]
		public var phase:String = OFF;
		
		[Bindable]
		public var tooltip:String = "Start simulator";
		
		public var error:String = null;
		private var output:String = "";
		
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		
		private static const xcrunExec:File = new File("/usr/bin/xcrun");
		private static const openExec:File = new File("/usr/bin/open");
		private static const xcodeBuildExec:File = new File("/usr/bin/xcodebuild");
		
		public function Simulator(uid:String, name:String, os:String)
		{
			this.uid = uid;
			this.name = name;
			this.os = os;
		}
		
		public function startStop():void{
			
			if(phase == OFF){
				phase = WAIT;
				tooltip = "Simulator is starting ...";
				
				procInfo.executable = xcrunExec;
				procInfo.workingDirectory = File.userDirectory;
				
				process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onEraseExit, false, 0, true);
				//process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData, false, 0, true);
				
				procInfo.arguments = new <String>["simctl", "erase", uid];
				process.start(procInfo);
			}else{
				phase = WAIT;
				tooltip = "Simulator is terminating ...";
				
				procInfo.executable = xcrunExec;
				process.addEventListener(NativeProcessExitEvent.EXIT, onShutdownExit, false, 0, true);
				
				procInfo.arguments = new <String>["simctl", "shutdown", uid];
				process.start(procInfo);
			}
		}
		
		protected function onShutdownExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onShutdownExit);
			phase = OFF;
			tooltip = "Start simulator";
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			trace(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
		}
		
		protected function onEraseExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onEraseExit);
			process.addEventListener(NativeProcessExitEvent.EXIT, onBootExit, false, 0, true);
			
			procInfo.arguments = new <String>["simctl", "boot", uid];
			process.start(procInfo);
		}
		
		protected function onBootExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onBootExit);
			process.addEventListener(NativeProcessExitEvent.EXIT, onSimulatorStartedExit, false, 0, true);
			
			procInfo.executable = openExec;
			procInfo.arguments = new <String>["-a", "simulator"];
			process.start(procInfo);
		}
		
		protected function onSimulatorStartedExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onSimulatorStartedExit);
			process.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingProgress, false, 0, true);
			
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = iosDriverProjectFolder;
			procInfo.arguments = new <String>["-workspace", "atsios.xcworkspace", "-scheme", "atsios", "'id=" + uid + "'", "test", "-quiet"];
			process.start(procInfo);
		}
		
		protected function onTestingProgress(event:ProgressEvent):void{
			output += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
			if(output.indexOf("Continuing with testing") > -1){
				phase = RUN;
				tooltip = "Shutdown simulator";
			}
		}
		
		protected function onTestingExit(event:NativeProcessExitEvent):void{
			trace("testing crashed")
		}
		
		
	}
}