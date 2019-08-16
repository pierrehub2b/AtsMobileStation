package device
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.utils.StringUtil;
	
	public class IosSimulator extends EventDispatcher
	{
		public static const STATUS_CHANGED:String = "statusChanged";
		
		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");

		public static const OFF:String = "off";
		public static const WAIT:String = "wait";
		public static const RUN:String = "run";
		
		public var id:String;
		
		[Bindable]
		public var name:String;
		
		[Bindable]
		public var version:String;
		
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
		
		public function IosSimulator(id:String, name:String, version:String)
		{
			this.id = id;
			this.name = StringUtil.trim(name);
			this.version = version;
		}
		
		public function startStop():void{
			
			if(phase == OFF){
				phase = WAIT;
				tooltip = "Simulator is starting ...";
				
				procInfo.executable = xcrunExec;
				procInfo.workingDirectory = File.userDirectory;
				
				process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onEraseExit, false, 0, true);

				procInfo.arguments = new <String>["simctl", "erase", id];
				process.start(procInfo);
			}else{
				
				phase = WAIT;
				tooltip = "Simulator is terminating ...";
				dispatchEvent(new Event(STATUS_CHANGED));
				
				procInfo.executable = xcrunExec;
				process.addEventListener(NativeProcessExitEvent.EXIT, onShutdownExit, false, 0, true);
				
				procInfo.arguments = new <String>["simctl", "shutdown", id];
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
			
			trace("Simulator image erased, booting simulator ...")
			
			procInfo.arguments = new <String>["simctl", "bootstatus", id, "-b"];
			process.start(procInfo);
		}
		
		protected function onBootExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onBootExit);
			process.addEventListener(NativeProcessExitEvent.EXIT, onSimulatorStartedExit, false, 0, true);
			
			trace("Simulator started, open simulator app ...")
			
			procInfo.executable = openExec;
			procInfo.arguments = new <String>["-a", "simulator"];
			process.start(procInfo);
		}
		
		protected function onSimulatorStartedExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onSimulatorStartedExit);
			
			phase = RUN;
			tooltip = "Shutdown simulator";
			dispatchEvent(new Event(STATUS_CHANGED));
			
			/*process.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingProgress, false, 0, true);
			
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = iosDriverProjectFolder;
			procInfo.arguments = new <String>["-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "id=" + uid, "test", "-quiet"];
			process.start(procInfo);*/

		}
	}
}