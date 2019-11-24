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
	
	public class AndroidUsbCaptureScreen extends EventDispatcher
	{
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
		
		private var baImage:ByteArray;
		
		public function AndroidUsbCaptureScreen(adbFile:File, atsdroid:String, id:String, port:String)
		{
			procInfo.executable = adbFile;
			procInfo.workingDirectory = adbFile.parent;
			
			//process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onScreenCaptureExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onScreenCaptureDataInit, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell"];
		}
		
		public function start():void{
			baImage = new ByteArray();
			process.start(procInfo);
		}
		
		protected function onScreenCaptureDataInit(event:ProgressEvent):void{
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onScreenCaptureDataInit);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onScreenCaptureData, false, 0, true);
			process.addEventListener(Event.COMPLETE, completeHandler);
			
			process.standardInput.writeUTF("screencap -p\n");
		}
		
		private function completeHandler(event:Event):void {
			trace("completeHandler: " + event);
		}
		
		private var pngReadStarted:Boolean = false;
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

					/*var loader:Loader = new Loader();
					loader.loadBytes(baImage);
					loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loaderComplete);*/
						
				}else{
					ba.readBytes(baImage, baImage.length);
				}
			}
		}
		
		public var bitmapData:BitmapData
		private function loaderComplete(ev:Event):void
		{
			var loaderInfo:LoaderInfo = LoaderInfo(ev.target);
			bitmapData = new BitmapData(loaderInfo.width, loaderInfo.height, false, 0xFFFFFF);
			bitmapData.draw(loaderInfo.loader);
			
			process.standardInput.writeUTF("screencap -p\n");
			dispatchEvent(new Event("screenCapture"));
		}
		
		protected function onScreenCaptureExit(event:NativeProcessExitEvent):void{
			trace("exit");
		}
	}
}