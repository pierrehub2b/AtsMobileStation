package device
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.utils.setInterval;
	
	public class IosDevice extends Device
	{
		private var output:String = "";
		
		private static const startInfo:RegExp = /ATSDRIVER_DRIVER_HOST=(.*):(\d+)/
		
		private var testingProcess:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		
		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");
		private static const xcodeBuildExec:File = new File("/usr/bin/env");
		
		public function IosDevice(id:String, name:String, isSimulator:Boolean, ip:String)
		{
			this.id = id;
			this.ip = "0.0.0.0";
			this.modelName = name;
			this.manufacturer = "Apple";
			this.isSimulator = isSimulator;
			this.isCrashed = false;
			
			installing()
			testingProcess.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
			testingProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError, false, 0, true);
			testingProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingOutput, false, 0, true);
			
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = iosDriverProjectFolder;
			procInfo.arguments = new <String>["xcodebuild", "-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "id=" + id, "test"];
			testingProcess.start(procInfo);
		}
		
		override public function dispose():Boolean
		{
			testingProcess.exit(true);
			return true;
		}
				
		protected function onTestingExit(event:NativeProcessExitEvent):void{
			testingProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
			testingProcess.removeEventListener(NativeProcessExitEvent.EXIT, onTestingExit);

			trace("testing exit");
			
		}
		
		protected function onTestingOutput(event:ProgressEvent):void
		{
			var data:String = testingProcess.standardOutput.readUTFBytes(testingProcess.standardOutput.bytesAvailable);
			trace("test output -> " + data);
			
			var find:Array = startInfo.exec(data);
			if(find != null){
				ip = find[1];
				port = find[2];
				started();
			}
		}
		
		protected function onTestingError(event:ProgressEvent):void
		{
			var data:String = testingProcess.standardError.readUTFBytes(testingProcess.standardError.bytesAvailable);
			trace("test error -> " + data);
			if(data.indexOf("Continuing with testing") < 0 && data.indexOf("** TEST EXECUTE FAILED **") > 0 || data.indexOf("** TEST FAILED **") > 0){
				this.changeCrashedStatus();
			}
		}
		
		protected function changeCrashedStatus():void {
			this.isCrashed = true
		}
	}
}