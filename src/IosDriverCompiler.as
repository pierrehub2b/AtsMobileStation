package
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.utils.StringUtil;

	public class IosDriverCompiler extends EventDispatcher
	{
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		private var compileProcess:NativeProcess = new NativeProcess();
		private var compileOutput:String = "";
		
		public function IosDriverCompiler()
		{
			procInfo.arguments = new <String>["xcodebuild", "-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "OS=13.0", "build-for-testing"];			
			procInfo.executable = new File("/usr/bin/env");
			procInfo.workingDirectory = File.applicationDirectory.resolvePath("assets/drivers/ios");

			compileProcess.addEventListener(NativeProcessExitEvent.EXIT, onCompileExit, false, 0, true);
			compileProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadCompileData, false, 0, true);
		}
		
		public function start():void{
			compileProcess.start(procInfo);
		}
		
		protected function onReadCompileData(event:ProgressEvent):void{
			compileOutput += StringUtil.trim(compileProcess.standardOutput.readUTFBytes(compileProcess.standardOutput.bytesAvailable));
		}
		
		protected function onCompileExit(event:NativeProcessExitEvent):void
		{
			compileProcess.removeEventListener(NativeProcessExitEvent.EXIT, onCompileExit);
			compileProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadCompileData);
			
			procInfo = null;
			procInfo = null;
			
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}
}