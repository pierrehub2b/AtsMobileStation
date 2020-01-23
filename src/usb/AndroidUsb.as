package usb
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.utils.ByteArray;
	
	public class AndroidUsb extends EventDispatcher
	{
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
			
		private var response:String = "";
		private var id:String = "";
		private var baImage:ByteArray;
		
		public function start(act:UsbAction):void{}
		
		protected function onUsbDataInit(event:ProgressEvent):void{}
		
		protected function onUsbActionExit(ev:NativeProcessExitEvent):void{}
		
		public function getResponse():String {
			return "";
		}
		
		public function getBaImage():ByteArray {
			return null;
		}
	}
}