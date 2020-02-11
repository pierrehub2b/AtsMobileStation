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
	
	import mx.core.EventPriority;
	
	import usb.UsbAction;
	
	public class UsbActionProcess extends EventDispatcher
	{
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		private var output:String = "";
		private var input:String = "";
		private var response:String = "";
		private var endOfShell:String = "";
		private var startingCommand:Boolean = false;
		
		public function UsbActionProcess(id:String)
		{
			var adbFile:File = File.applicationDirectory.resolvePath(
				AtsMobileStation.isMacOs ? RunningDevicesManager.adbPath : RunningDevicesManager.adbPath + ".exe"
			);
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = File.userDirectory;
			
			procInfo.arguments = new <String>["-s", id, "shell"];
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbActionProcessOutput, false, 0, true);
			
			process.start(procInfo);
		}
		
		public function stopProcess():void {
			process.exit(true);
		}
		
		protected function onUsbActionProcessOutput(event:ProgressEvent):void{
			output += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
			dataTraitment();
		}
		
		public function requestAction(act:UsbAction, startCommand:Boolean): void {
			input = "";
			output = "";
			if(act != null && act.getArgs.length > 0) {
				for(var i:int = 0;i<act.getArgs.length;i++) {
					input += act.getArgs[i] + " ";
				}
				startingCommand = startCommand;
				process.standardInput.writeUTFBytes(input + "\n");
			}
			
		}
		
		protected function dataTraitment():void {
			response = "";
			if(output.indexOf(RunningDevicesManager.responseSplitter) > -1 || startingCommand) {
				var outputSplitted:Array = output.split(RunningDevicesManager.responseSplitter);
				if(outputSplitted.length > 0) {
					response = outputSplitted[1];
				}
				
				if(startingCommand) {
					dispatchEvent(new Event(AndroidProcess.USBSTARTENDEDRESPONSE));
				} else if(input.indexOf("activity") > -1 && input.indexOf("package") == -1) {
					dispatchEvent(new Event(AndroidProcess.USBACTIONRESPONSE));
				} else if(input.indexOf("package") > -1) {
					var jsonObject:Object = JSON.parse(response);
					response = jsonObject["activityName"].toString();
					dispatchEvent(new Event(AndroidProcess.USBSTARTRESPONSE));
				}
			}
			output = "";
		}
		
		public function getResponse():String {
			return this.response;
		}
	}
}