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
	import flash.utils.ByteArray;
	
	public class AndroidUsbCaptureScreen extends AndroidUsb
	{
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
			
		private var androidOutput:String;
		private var baImage:ByteArray;
		public var targetFile:File;
		
		public function AndroidUsbCaptureScreen(id:String)
		{
			var adbFile:File = File.applicationDirectory.resolvePath(RunningDevicesManager.adbPath + ".exe");
			procInfo.executable = adbFile;
			procInfo.workingDirectory = adbFile.parent;
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onUsbActionExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbDataInit, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "dumpsys", "activity", AndroidProcess.ANDROIDDRIVER, "screenshot", "lores"];
		}
		
		public override function start(data:Array):void{
			this.baImage = new ByteArray();
			process.start(procInfo);
		}
		
		protected override function onUsbDataInit(event:ProgressEvent):void{
			androidOutput = androidOutput.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		private var pngReadStarted:Boolean = false;
		protected function onScreenCaptureData(bytes:ByteArray):void{
			
			var ba:ByteArray = bytes;
			
			const check:String = ba.toString();
			if(pngReadStarted || check.indexOf("PNG") >= 0){
				pngReadStarted = true;
				const iend:int = check.indexOf("IEND");
				if(iend > -1){
					ba.readBytes(this.baImage, this.baImage.length, iend+9);
					
					//trace(baImage.toString());
					
					var fs : FileStream = new FileStream();
					targetFile = File.userDirectory.resolvePath("pic.png");
					fs.open(targetFile, FileMode.WRITE);
					fs.writeBytes(this.baImage,0,this.baImage.length);
					fs.close();
					
					pngReadStarted = false;
					this.baImage = new ByteArray();
				}else{
					ba.readBytes(this.baImage, this.baImage.length);
				}
			}
		}
		
		protected override function onUsbActionExit(ev:NativeProcessExitEvent):void{
			process = ev.currentTarget as NativeProcess;
			var output:Array = androidOutput.split("\r\r\n");
			var response:String = "";
			for(var i:int=2;i<output.length;i++) {
				response += output[i];
				if(i != output.length-1) {
					response += "\r\r\n";
				}
			}
			var bytes:ByteArray = new ByteArray();
			bytes.writeMultiByte(response, "iso-8859-1");
			onScreenCaptureData(bytes);
			dispatchEvent(new Event(AndroidProcess.USBSCREENSHOTRESPONSE));
		}
		
		public override function getFile():File {
			return this.targetFile;
		}
	}
}