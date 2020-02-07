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
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onUsbScreenshotProcessExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbScreenshotProcessOutput, false, 0, true);
			
			process.start(procInfo);
		}
		
		protected function onUsbScreenshotProcessOutput(event:ProgressEvent):void{
			output = output.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
			if(output.substring(0,6) == "shell@" && endOfShell == "") {
				endOfShell = output;
			}
		}
		
		protected function onUsbScreenshotProcessExit(ev:NativeProcessExitEvent):void {
			process.start(procInfo);
		}
		
		public function requestScreenshot(act:UsbAction): void {
			var input:String = "";
			for(var i:int = 0;i<act.getArgs.length;i++) {
				input += act.getArgs[i] + " ";
			}
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, dataTraitment, false, 0, true);
			output = "";
			process.standardInput.writeUTFBytes(input + "\r\n");
		}
		
		public function closeProcess():void {
			process.closeInput();
		}
		
		protected function dataTraitment(ev:ProgressEvent):void {
			response = "";
			if(output.indexOf(endOfShell) > -1) {
				output = output.replace(endOfShell, "");
				var outputSplitted:Array = output.split("\r\n");
				output = "";
				for(var j:int = 2;j<outputSplitted.length;j++) {
					response += outputSplitted[j];
					if(j != outputSplitted.length-1 && this.procInfo.arguments[6] != "screenshot") {
						response += "\r\n";
					}
				}
				dispatchEvent(new Event(AndroidProcess.SCREENSHOTRESPONSE));
			}
		}
		
		public function getResponse():String {
			return this.response;
		}
	}
}