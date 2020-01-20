package device.running
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.Socket;
	import flash.system.Capabilities;
	import flash.text.ReturnKeyLabel;
	import flash.utils.ByteArray;
	
	public class AndroidUsbActions extends AndroidUsb
	{
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
		
		private var androidOutput:String;
		private var response:String = "";
		private var id:String = "";
		private var udpServerPort:String = "";
		
		public function AndroidUsbActions(id:String)
		{
			this.id = id;
			var adbFile:File = File.applicationDirectory.resolvePath(
				AtsMobileStation.isMacOs ? RunningDevicesManager.adbPath : RunningDevicesManager.adbPath + ".exe"
			);
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = File.userDirectory;
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onUsbActionExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbDataInit, false, 0, true);
		}
		
		public override function start(args:Array):void{
			androidOutput = "";
			procInfo.arguments = new <String>["-s", this.id, "shell", "dumpsys", "activity", AndroidProcess.ANDROIDDRIVER];;
			
			for(var i:int=0; i<args.length; i++){
				procInfo.arguments.push(args[i]);
			}
			process.start(procInfo);
		}
		
		protected override function onUsbDataInit(event:ProgressEvent):void{
			androidOutput = androidOutput.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected override function onUsbActionExit(ev:NativeProcessExitEvent):void
		{
			process = ev.currentTarget as NativeProcess;
			var output:Array = androidOutput.split("\r\n");
			if(this.procInfo.arguments[6] == "screenshot") {
				this.response = "";
				for(var i:int=2;i<output.length;i++) {
					this.response += output[i];
					if(i != output.length-1) {
						this.response += "\r\r\n";
					}
				}
			} else {
				this.response = output[output.length-1];
			}
			dispatchEvent(new Event(AndroidProcess.USBACTIONRESPONSE));
		}
		
		public override function getResponse():String {
			return this.response;
		}
	}
}