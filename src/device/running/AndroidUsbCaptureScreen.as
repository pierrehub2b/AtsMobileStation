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
			
		private var baImage:ByteArray;
		private var pngReadStarted:Boolean = false;
		public var bitmapData:BitmapData
		
		public function AndroidUsbCaptureScreen(id:String)
		{
			var adbFile:File = File.applicationDirectory.resolvePath(
				AtsMobileStation.isMacOs ? RunningDevicesManager.adbPath : RunningDevicesManager.adbPath + ".exe"
			);
			procInfo.executable = adbFile;
			procInfo.workingDirectory = adbFile.parent;
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onUsbActionExit, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "dumpsys", "activity", AndroidProcess.ANDROIDDRIVER, "screenshot", "screenshot", "lores"];
		}
		
		public override function start(data:Array):void{
			this.baImage = new ByteArray();
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbDataInit, false, 0, true);
			process.start(procInfo);
		}
		
		protected override function onUsbDataInit(event:ProgressEvent):void {
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUsbDataInit);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onScreenCaptureData, false, 0, true);
			process.addEventListener(Event.COMPLETE, completeHandler);
		}
		
		protected function onScreenCaptureData(ev:ProgressEvent):void{
			
			var ba:ByteArray = new ByteArray();
			process.standardOutput.readBytes(ba);
			
			const check:String = ba.toString();
			if(pngReadStarted || check.indexOf("PNG") >= 0){
				pngReadStarted = true;
				const iend:int = check.indexOf("IEND");
				if(iend > -1){
					ba.readBytes(baImage, baImage.length, iend+9);
					
					//trace(baImage.toString());
					
					var fs : FileStream = new FileStream();
					var targetFile : File = File.userDirectory.resolvePath("pic.png");
					fs.open(targetFile, FileMode.WRITE);
					fs.writeBytes(baImage,0,baImage.length);
					fs.close();
					
					pngReadStarted = false;
					baImage = new ByteArray();
					process.standardInput.writeUTF("screencap -p\n");
					
					var loader:Loader = new Loader();
					loader.loadBytes(baImage);
					loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loaderComplete);
					
				}else{
					ba.readBytes(baImage, baImage.length);
				}
			}
		}
		
		private function loaderComplete(ev:Event):void
		{
			var loaderInfo:LoaderInfo = LoaderInfo(ev.target);
			bitmapData = new BitmapData(loaderInfo.width, loaderInfo.height, false, 0xFFFFFF);
			bitmapData.draw(loaderInfo.loader);
			
			process.standardInput.writeUTF("screencap -p\n");
			dispatchEvent(new Event(AndroidProcess.USBSCREENSHOTRESPONSE));
		}
		
		protected override function onUsbActionExit(event:NativeProcessExitEvent):void{
			trace("exit");
		}
		
		private function completeHandler(event:Event):void {
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onScreenCaptureData);
			process.removeEventListener(Event.COMPLETE, completeHandler);
			trace("completeHandler: " + event);
		}
		
		public override function getBaImage():ByteArray {
			return this.baImage;
		}
	}
}