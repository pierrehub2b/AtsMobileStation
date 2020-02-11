package usb
{
	import device.running.AndroidProcess;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import usb.UsbAction;
	
	public class UsbScreenshotProcess extends EventDispatcher
	{
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		private var output:String = "";
		private var response:String = "";
		private var endOfShell:String = "";
		
		public function UsbScreenshotProcess(id:String)
		{
			var adbFile:File = File.applicationDirectory.resolvePath(
				AtsMobileStation.isMacOs ? RunningDevicesManager.adbPath : RunningDevicesManager.adbPath + ".exe"
			);
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = File.userDirectory;
			
			procInfo.arguments = new <String>["-s", id, "shell"];
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbScreenshotProcessOutput, false, 0, true);
			
			process.start(procInfo);
		}
		
		protected function onUsbScreenshotProcessOutput(event:ProgressEvent):void{
			output = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
			dataTraitment();
		}
		
		protected function onUsbScreenshotProcessExit(ev:NativeProcessExitEvent):void {
			process.start(procInfo);
		}
		
		public function requestScreenshot(act:UsbAction): void {
			var input:String = "";
			output = "";
			for(var i:int = 0;i<act.getArgs.length;i++) {
				input += act.getArgs[i] + " ";
			}
			process.standardInput.writeUTFBytes(input + "\n");
		}
		
		public function stopProcess():void {
			process.exit(true);
		}
		
		protected function dataTraitment():void {
			response = "";
			if(output.indexOf(RunningDevicesManager.responseSplitter) > -1) {
				var outputSplitted:Array = output.split(RunningDevicesManager.responseSplitter);
				output = "";
				
				if(outputSplitted.length > 0) {
					response = outputSplitted[1];
				}
				dispatchEvent(new Event(AndroidProcess.SCREENSHOTRESPONSE));
			}
			output = "";
		}
		
		public function getResponse():String {
			return this.response;
		}
	}
}