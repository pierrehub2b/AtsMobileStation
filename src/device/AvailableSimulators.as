package device
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	import mx.utils.StringUtil;

	public class AvailableSimulators
	{
		private var regex:RegExp = /iPhone(.*)\([\)]*)\)\[(.*)\](.*)/
		protected var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		protected var process:NativeProcess = new NativeProcess();
		
		private var output:String = "";
		
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		public function AvailableSimulators()
		{
			procInfo.executable = new File("/usr/bin/instruments");
			procInfo.workingDirectory = File.userDirectory;
			
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onInstrumentsOutput, false, 0, true);
			
			procInfo.arguments = new <String>["-s", "devices"];
			process.start(procInfo);
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			trace(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
		}
		
		protected function onInstrumentsOutput(event:ProgressEvent):void{
			output += StringUtil.trim(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onInstrumentsExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onInstrumentsExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onInstrumentsOutput);
			
			var list:Array = output.split("\n");
			for each(var line:String in list){
				if(line.indexOf("iPhone") == 0){
					var data:Array = regex.exec(line);
					//data[2]
					trace(data)
				}
			}
		}
		
	}
}