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
	
	public class AndroidUsb extends EventDispatcher
	{
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()

		private var response:String = "";
		private var id:String = "";
		private var baImage:ByteArray;
		
		public function start(args:Array):void{}
		
		protected function onUsbDataInit(event:ProgressEvent):void{}
		
		protected function onUsbActionExit(ev:NativeProcessExitEvent):void{}
		
		public function getResponse():String {
			return "";
		}
		
		public function getFile():File {
			return null;
		}
	}
}