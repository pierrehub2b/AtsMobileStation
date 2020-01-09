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
	import flash.text.ReturnKeyLabel;
	import flash.utils.ByteArray;
	
	public class AndroidUsbActions extends EventDispatcher
	{
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
		
		private var androidOutput:String;
		
		private var response:String = "";
		private var id:String = "";
		
		public function AndroidUsbActions(id:String)
		{
			this.id = id;
			var adbFile:File = File.applicationDirectory.resolvePath(RunningDevicesManager.adbPath + ".exe");
			
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = File.userDirectory;
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onUsbActionExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbDataInit, false, 0, true);
		}
		
		public function get Response():String {
			return this.response;
		}
		
		public function start(args:Array):void{
			androidOutput = "";
			procInfo.arguments = new <String>["-s", id, "shell", "dumpsys", "activity", AndroidProcess.ANDROIDDRIVER];;
			
			for(var i:int=0; i<args.length; i++){
				procInfo.arguments.push(args[i]);
			}
			process.start(procInfo);
		}
		
		protected function onUsbDataInit(event:ProgressEvent):void{
			androidOutput = androidOutput.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onUsbActionExit(ev:NativeProcessExitEvent):void
		{
			process = ev.currentTarget as NativeProcess;
			var output:Array = androidOutput.split("\r\r\n");
			response = output[output.length-1];
			dispatchEvent(new Event(AndroidProcess.USBACTIONRESPONSE));
		}
	}
}