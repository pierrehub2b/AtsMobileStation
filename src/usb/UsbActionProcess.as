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
		
		public function UsbActionProcess(id:String)
		{
			var adbFile:File = File.applicationDirectory.resolvePath(
				AtsMobileStation.isMacOs ? RunningDevicesManager.adbPath : RunningDevicesManager.adbPath + ".exe"
			);
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = File.userDirectory;
			
			procInfo.arguments = new <String>["-s", id, "shell"];
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onUsbActionProcessExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbActionProcessOutput, false, 0, true);
			
			process.start(procInfo);
		}
		
		public function closeProcess():void {
			process.closeInput();
		}
		
		protected function onUsbActionProcessOutput(event:ProgressEvent):void{
			output = output.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
			if(output.substring(0,6) == "shell@" && endOfShell == "") {
				endOfShell = output
			}
		}

		protected function onUsbActionProcessExit(ev:NativeProcessExitEvent):void {
			process.start(procInfo);
		}
		
		public function requestAction(act:UsbAction): void {
			input = "";
			if(act != null && act.getArgs.length > 0) {
				for(var i:int = 0;i<act.getArgs.length;i++) {
					input += act.getArgs[i] + " ";
				}
				//input = trimWhitespace(input);
				output = "";
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, dataTraitment, false, 0, true);
				process.standardInput.writeUTFBytes(input + "\r\n");
			}
			
		}
		
		protected function dataTraitment(ev:ProgressEvent):void {
			response = "";
			if(output.indexOf(endOfShell) > -1) {
				output = output.replace(endOfShell, "");
				var outputSplitted:Array = output.split("\r\n");
				output = "";
				response = outputSplitted[outputSplitted.length-1];
				
				/*for(var j:int = 3;j<outputSplitted.length;j++) {
					response += outputSplitted[j];
					if(j != outputSplitted.length-1 && input.indexOf("screenshot hires") > -1) {
						response += "\r\n";
					}
				}*/
				
				try {
					if(input.indexOf("am start") > -1) {
						dispatchEvent(new Event(AndroidProcess.USBSTARTENDEDRESPONSE));
						return;
					}
					var jsonObject:Object = JSON.parse(response);
					if(input.indexOf("activity") > -1 && input.indexOf("package") == -1) {
						dispatchEvent(new Event(AndroidProcess.USBACTIONRESPONSE));
					} else if(input.indexOf("package") > -1) {
						response = jsonObject["activityName"].toString();
						dispatchEvent(new Event(AndroidProcess.USBSTARTRESPONSE));
					}
				} catch (er:Error) {
					var error:String = er.message;
				}
			}
		}
		
		private function trimWhitespace(string:String):String {
			if (string == null) {
				return "";
			}
			return string.replace(/^\s+|\s+$/g, "");
		}
		
		public function getResponse():String {
			return this.response;
		}
	}
}