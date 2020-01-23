package udpServer
{
	import flash.display.Sprite;
	import flash.events.DatagramSocketDataEvent;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.net.DatagramSocket;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFieldType;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import device.running.AndroidProcess;
	
	import usb.AndroidUsb;
	import usb.AndroidUsbActions;
	import usb.AndroidUsbCaptureScreen;
	import usb.UsbAction;
	
	public class ScreenshotServer extends Sprite
	{
		public var _datagramSocket:DatagramSocket = new DatagramSocket();;
		
		private var _sourceIp:String;
		private var _sourcePort:String;
		private var _message:TextField;
		private var androidUsb:AndroidUsb;
		
		public function ScreenshotServer(){
			_datagramSocket = new DatagramSocket();
		}
		
		public function bind(ip:String, id:String):void
		{
			if(_datagramSocket.bound) 
			{
				_datagramSocket.close();
				_datagramSocket = new DatagramSocket();
			}
			this.androidUsb = new AndroidUsbCaptureScreen(id);
			_datagramSocket.bind(0,ip);
			_datagramSocket.addEventListener(DatagramSocketDataEvent.DATA, dataReceived);
			_datagramSocket.receive();
		}
		
		private function dataReceived(event:DatagramSocketDataEvent):void
		{
			androidUsb.addEventListener(AndroidProcess.USBSCREENSHOTRESPONSE, usbActionResponseEnded, false, 0, true);
			androidUsb.start(new UsbAction(new Array()));
		}
		
		private function usbActionResponseEnded(ev:Event):void {
			if(androidUsb.getBaImage() != null && androidUsb.getBaImage().bytesAvailable > 0) {
				_datagramSocket.send(androidUsb.getBaImage(), 0, 0, _sourceIp, parseInt(_sourcePort));
			}
		}
	}
}