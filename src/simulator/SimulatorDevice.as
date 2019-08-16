package simulator
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import device.Device;

	public class SimulatorDevice extends Device
	{
		private static const phpRouterFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/router.php").nativePath;
			
		public var error:String = null;
		private var output:String = "";
		
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
			
		public function SimulatorDevice(port:int)
		{
			procInfo.executable = new File("/usr/bin/php");			
			procInfo.workingDirectory = File.userDirectory;
			
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onReadLanExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData, false, 0, true);
			
			procInfo.arguments = new <String>["-S", "0.0.0.0:" + port, phpRouterFilePath];
			process.start(procInfo);
		}
		
		override public function dispose():Boolean{
			if(process.running){
				process.exit(true);
				return true;
			}
			return false;
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadLanExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData);
			
			error = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			trace(error)
		}
		
		protected function onReadLanData(event:ProgressEvent):void{
			output += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
		}
		
		protected function onReadLanExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadLanExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData);
			
			trace(output);
		}
	}
}