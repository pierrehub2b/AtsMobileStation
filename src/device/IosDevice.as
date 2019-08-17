package device
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;

	public class IosDevice extends Device
	{
		private var output:String = "";
		
		private var testingProcess:NativeProcess = new NativeProcess();

		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");
		private static const phpRouterFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/router.php").nativePath;
		private static const xcodeBuildExec:File = new File("/usr/bin/xcodebuild");
		private static const phpExec:File = new File("/usr/bin/php");

		public function IosDevice(id:String, name:String, isSimulator:Boolean, ip:String)
		{
			this.id = id;
			this.ip = ip;
			this.modelName = name;
			this.manufacturer = "Apple";
			this.isSimulator = isSimulator;
			
			status = INSTALL
			
			testingProcess.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
			testingProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
			testingProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingProgress, false, 0, true);
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = iosDriverProjectFolder;
			procInfo.arguments = new <String>["-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "id=" + id, "test", "-quiet"];
			testingProcess.start(procInfo);
		}
		
		protected function onTestingError(event:ProgressEvent):void
		{
			testingProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
			testingProcess.removeEventListener(NativeProcessExitEvent.EXIT, onTestingExit);
			testingProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingProgress);
			
			trace(testingProcess.standardError.readUTFBytes(testingProcess.standardError.bytesAvailable));
		}
		
		protected function onTestingProgress(event:ProgressEvent):void{
			output = testingProcess.standardOutput.readUTFBytes(testingProcess.standardOutput.bytesAvailable);
			trace(output);
		}
		
		protected function onTestingExit(event:NativeProcessExitEvent):void{
			
			testingProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
			testingProcess.removeEventListener(NativeProcessExitEvent.EXIT, onTestingExit);
			testingProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingProgress);
			

		}
		
	}
}