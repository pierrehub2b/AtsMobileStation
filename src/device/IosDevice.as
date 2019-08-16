package device
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;

	public class IosDevice extends Device
	{
		public var error:String = null;
		private var output:String = "";
		
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()

		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");
		private static const phpRouterFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/router.php").nativePath;
		private static const xcodeBuildExec:File = new File("/usr/bin/xcodebuild");
		private static const phpExec:File = new File("/usr/bin/php");

		public function IosDevice(id:String, name:String, ip:String)
		{
			this.ip = ip;
			this.modelName = name;
			this.manufacturer = "Apple";
			
			/*process.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingProgress, false, 0, true);
			
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = iosDriverProjectFolder;
			procInfo.arguments = new <String>["-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "id=" + id, "test", "-quiet"];
			process.start(procInfo);*/
		}
	}
}