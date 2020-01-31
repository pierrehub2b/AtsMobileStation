package udpServer
{
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	
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
		private static const PACKET_SIZE:int = 2000;
		private var pngReadStarted:Boolean = false;
		public var bitmapData:BitmapData;
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
			//Create a message in a ByteArray
			var data:ByteArray = new ByteArray();
			data.writeUTFBytes(currentDevice.androidUsb.getResponse());
			dataTraitment(data);
		}
		
		public function sendData(screen:ByteArray, currentPos:int, dataLength:int, packetSize:int):void {
			//var bytes:[] = getData(currentPos, dataLength, packetSize);
			var bytes:ByteArray = new ByteArray();
			for(var i:int=0; i < packetSize; i++) {
				bytes[i] = screen[currentPos + i];
			}
			
			_datagramSocket.send(bytes, 0, bytes.length, _datagramSocket.localAddress, _datagramSocket.localPort);
		}
		
		
		protected function dataTraitment(data:ByteArray):void{			
			const check:String = data.toString();
			baImage = new ByteArray();
			if(pngReadStarted || check.indexOf("PNG") >= 0){
				pngReadStarted = true;
				const iend:int = check.indexOf("IEND");
				if(iend > -1){
					baImage.writeBytes(data,8,iend+9);
					
					//trace(baImage.toString());
					
					var fs : FileStream = new FileStream();
					var targetFile : File = File.userDirectory.resolvePath("pic.png");
					fs.open(targetFile, FileMode.WRITE);
					fs.writeBytes(baImage,0,baImage.length);
					fs.close();
					
					pngReadStarted = false;
					
					var loader:Loader = new Loader();
					loader.loadBytes(baImage);
					loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loaderComplete);
					
				}else{
					data.readBytes(baImage, baImage.length);
				}
			}
		}
		
		private function loaderComplete(ev:Event):void
		{
			var loaderInfo:LoaderInfo = LoaderInfo(ev.target);
			bitmapData = new BitmapData(loaderInfo.width, loaderInfo.height, false, 0xFFFFFF);
			bitmapData.draw(loaderInfo.loader);
			
			
			var myBitmapData:BitmapData = new BitmapData(loaderInfo.width, loaderInfo.width);
			myBitmapData.drawWithQuality(bitmapData,null,null,null,null,false,StageQuality.MEDIUM);
			
			//Send a datagram to the target
			try
			{
				var bounds:Rectangle = new Rectangle(0, 0, myBitmapData.width, myBitmapData.height);
				var data:ByteArray = myBitmapData.getPixels(bounds);
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
		
		/*private function getData(dataPos:int, dataLength:int, packetSize:int):[] {
			var data:[] = new [packetSize + 8];
			
			data[0] = (dataPos >>> 24);
			data[1] = (dataPos >>> 16);
			data[2] = (dataPos >>> 8);
			data[3] = (dataPos);
			
			data[4] = (dataLength >>> 24);
			data[5] = (dataLength >>> 16);
			data[6] = (dataLength >>> 8);
			data[7] = (dataLength);
			
			return data;
		}*/
		

	}
}