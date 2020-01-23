package usb
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import device.Device;
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	
	public class AndroidUsbActions extends AndroidUsb
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
		
		public override function start(act:UsbAction):void{
			if(!process.running) {
				androidOutput = "";
				procInfo.arguments = new <String>["-s", this.currentDevice.id, "shell", "dumpsys", "activity", AndroidProcess.ANDROIDDRIVER];
				for(var i:int=0; i<act.getArgs.length; i++){
					procInfo.arguments.push(act.getArgs[i]);
				}
				process.start(procInfo);
			}
		}
		
		protected override function onUsbDataInit(event:ProgressEvent):void{
			androidOutput = androidOutput.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected override function onUsbActionExit(ev:NativeProcessExitEvent):void
		{
			this.response = "";
			if(androidOutput.indexOf("Bad activity command") == -1) {
				process = ev.currentTarget as NativeProcess;
				var output:Array = androidOutput.split("\r\n");
				if(this.procInfo.arguments[6] == "screenshot") {
					this.response = "";
					for(var i:int=2;i<output.length;i++) {
						this.response += output[i];
						if(i != output.length-1) {
							this.response += "\r\n";
						}
					}
				} else {
					this.response = output[output.length-1];
				}
				dispatchEvent(new Event(AndroidProcess.USBACTIONRESPONSE));
			} else {
				dispatchEvent(new Event(AndroidProcess.USBACTIONERROR));
			}
		}
		
		public override function getResponse():String {
			return this.response;
		}
	}
}