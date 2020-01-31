package usb
{
	import device.Device;
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.events.EventDispatcher;
	
	public class AndroidUsbActions extends EventDispatcher
	{
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
		
		private var androidOutput:String;
		private var response:String = "";
		private var currentDevice:AndroidDevice;
		private var udpServerPort:String = "";
		private var error:String = "";
		
		public function AndroidUsbActions(currentDevice:AndroidDevice)
		{
			this.currentDevice = currentDevice;
			var adbFile:File = File.applicationDirectory.resolvePath(
				AtsMobileStation.isMacOs ? RunningDevicesManager.adbPath : RunningDevicesManager.adbPath + ".exe"
			);
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = File.userDirectory;
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onUsbActionExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbDataInit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onUsbDataError, false, 0, true);
		}
		
		protected function onUsbDataError(event:ProgressEvent):void
		{
			error = new String(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
		}
		
		public function start(act:UsbAction):void{
			if(!process.running) {
				androidOutput = "";				
				procInfo.arguments = new <String>["-s", this.currentDevice.id, "shell"];
				for(var i:int=0; i<act.getArgs.length; i++){
					procInfo.arguments.push(act.getArgs[i]);
				}
				process.start(procInfo);
			}
		}
		
		protected function onUsbDataInit(event:ProgressEvent):void{
			androidOutput = androidOutput.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onUsbActionExit(ev:NativeProcessExitEvent):void
		{
			this.response = "";
			if(androidOutput.indexOf("Bad activity command") == -1) {
				process = ev.currentTarget as NativeProcess;
				var output:Array = androidOutput.split("\r\n");
				if(this.procInfo.arguments.length > 6 && this.procInfo.arguments[6] == "screenshot") {
					var outputJsonScreen:String = androidOutput.split("\r\n")[androidOutput.split("\r\n").length-1];
					var jsonObjectScreen:Object = JSON.parse(outputJsonScreen);
					this.response = jsonObjectScreen["data"].toString();
					dispatchEvent(new Event(AndroidProcess.SCREENSHOTRESPONSE));
					return;
				} else {
					this.response = output[output.length-1];
				}
				if(this.procInfo.arguments[4] == "activity" && this.procInfo.arguments[6] != "package") {
					dispatchEvent(new Event(AndroidProcess.USBACTIONRESPONSE));
				} else if(this.procInfo.arguments[6] == "package") {
					var outputJson:String = androidOutput.split("\r\n")[androidOutput.split("\r\n").length-1];
					var jsonObject:Object = JSON.parse(outputJson);
					this.response = jsonObject["activityName"].toString();
					dispatchEvent(new Event(AndroidProcess.USBSTARTRESPONSE));
				} else {
					dispatchEvent(new Event(AndroidProcess.USBSTARTENDEDRESPONSE));
				}
			} else {
				dispatchEvent(new Event(AndroidProcess.USBACTIONERROR));
			}
		}
		
		public function getResponse():String {
			return this.response;
		}
	}
}