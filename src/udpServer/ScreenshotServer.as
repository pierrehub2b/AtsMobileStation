package udpServer
{
	import com.sociodox.utils.Base64;
	
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.Sprite;
	import flash.display.StageQuality;
	import flash.events.DatagramSocketDataEvent;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Rectangle;
	import flash.net.DatagramSocket;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFieldType;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import mx.utils.Base64Decoder;
	import mx.utils.Base64Encoder;
	
	import usb.AndroidUsbActions;
	import usb.UsbAction;
	
	public class ScreenshotServer extends Sprite
	{
		public var _datagramSocket:DatagramSocket = new DatagramSocket();;
		
		private var _sourceIp:String;
		private var _sourcePort:String;
		private var _message:TextField;
		private var androidUsb:AndroidUsbActions;
		private var currentDevice:AndroidDevice;
		private static const PACKET_SIZE:int = 1468;
		private var baImage:ByteArray = new ByteArray();
		
		public function ScreenshotServer(){
			_datagramSocket = new DatagramSocket();
		}
		
		public function bind(ip:String, device:AndroidDevice):void
		{
			this.currentDevice = device;
			if(_datagramSocket.bound) 
			{
				_datagramSocket.close();
				_datagramSocket = new DatagramSocket();
			}
			_datagramSocket.bind(0,ip);
			_datagramSocket.addEventListener(DatagramSocketDataEvent.DATA, dataReceived);
			_datagramSocket.receive();
		}
		
		private function dataReceived(event:DatagramSocketDataEvent):void
		{
			var data:Array = new Array();
			data.push("dumpsys", "activity", AndroidProcess.ANDROIDDRIVER, "screenshot", "hires");
			
			currentDevice.androidUsb.addEventListener(AndroidProcess.SCREENSHOTRESPONSE, sendBackData, false, 0, true);
			
			currentDevice.actionsInsertAt(0, new UsbAction(data));
			var usbAction:UsbAction = currentDevice.actionsShift();
			currentDevice.androidUsb.start(usbAction);
		}
		
		public function sendBackData(ev:Event):void
		{
			//var decoder:Base64Decoder = new Base64Decoder();
			//decoder.decode();
			var ba:ByteArray = new ByteArray();
			ba.writeUTFBytes(currentDevice.androidUsb.getResponse());
			//ba.position = 0;
			var rect:Rectangle = new Rectangle(0,0,parseInt(currentDevice.androidUsb.getWidth()),parseInt(currentDevice.androidUsb.getHeight()));
			var newBmd:BitmapData = new BitmapData(rect.width,rect.height,true,0xFFFFFFFF);
			newBmd.setPixels(rect, ba);
			newBmd.drawWithQuality(newBmd,null,null,null,null,false,StageQuality.MEDIUM);
			
			//Send a datagram to the target
			try
			{
				var data:ByteArray = newBmd.getPixels(rect);
				var dataLength:int = data.length;
				
				var packetSize:int = PACKET_SIZE;
				var currentPos:int = 0;
				
				sendData(data, 0, data.length, PACKET_SIZE);
				
				while (dataLength > 0) {
					currentPos += packetSize;
					dataLength -= packetSize;
					if (dataLength < packetSize) {
						packetSize = dataLength;
					}
					sendData(data, currentPos, dataLength, packetSize);
				}
			}
			catch ( error:Error ){
				var errorStr:String = error.message;
			}
		}
		
		public function sendData(screen:ByteArray, currentPos:int, dataLength:int, packetSize:int):void {
			var bytes:ByteArray = new ByteArray();
			for(var i:int=0; i < packetSize; i++) {
				bytes[i] = screen[currentPos + i];
			}
			
			_datagramSocket.send(bytes, 0, bytes.length, _datagramSocket.localAddress, _datagramSocket.localPort);
		}
	}
}