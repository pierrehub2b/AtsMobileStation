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
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		
		private var phpProcess:NativeProcess
		
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
			trace("Install atsios driver ...");
			
			testingProcess.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
			testingProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError, false, 0, true);
			
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = iosDriverProjectFolder;
			procInfo.arguments = new <String>["-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "id=" + id, "test", "-quiet"];
			testingProcess.start(procInfo);
		}
		
		override public function dispose():Boolean
		{
			testingProcess.exit(true);
			if(phpProcess != null && phpProcess.running){
				phpProcess.exit(true);
			}
		}
				
		protected function onTestingExit(event:NativeProcessExitEvent):void{
			testingProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
			testingProcess.removeEventListener(NativeProcessExitEvent.EXIT, onTestingExit);
		}
		
		protected function onTestingError(event:ProgressEvent):void
		{
			var data:String = testingProcess.standardError.readUTFBytes(testingProcess.standardError.bytesAvailable));
			trace("data -> " + data);
			if(data.indexOf("Continuing with testing") != -1){
				if(isSimulator){
					trace("atsios driver started, launch php server ...");
					
					phpProcess = new NativeProcess();
					phpProcess.addEventListener(NativeProcessExitEvent.EXIT, onPhpExit, false, 0, true);
					phpProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onPhpData, false, 0, true);
					
					var phpProcessInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
					phpProcessInfo.executable = phpExec;			
					phpProcessInfo.workingDirectory = File.userDirectory;
					
					procInfo.arguments = new <String>["-S", "0.0.0.0:" + port, phpRouterFilePath];
					phpProcess.start(procInfo);
				}else{
					status = READY
				}
			}
		}
		
		protected function onPhpData(event:ProgressEvent):void{
			phpProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onPhpData);
			trace("Php server started ...");
			status = READY
		}
		
		protected function onPhpExit(event:NativeProcessExitEvent):void{
			phpProcess.removeEventListener(NativeProcessExitEvent.EXIT, onPhpExit);
			phpProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onPhpData);
		}	
	}
}