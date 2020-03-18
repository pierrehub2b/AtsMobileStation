package udpServer
{
	import com.worlize.websocket.WebSocket;
	import com.worlize.websocket.WebSocketErrorEvent;
	import com.worlize.websocket.WebSocketEvent;
	import com.worlize.websocket.WebSocketMessage;
	
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.StageQuality;
	import flash.events.DatagramSocketDataEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Rectangle;
	import flash.net.DatagramSocket;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	
	import mx.utils.Base64Decoder;
	
	import usb.UsbAction;
	
	public class ScreenshotServer
	{
		public var _datagramSocket:DatagramSocket = new DatagramSocket();;
		
		private var _sourceIp:String;
		private var _sourcePort:String;
		private var _message:TextField;
		private var currentDevice:AndroidDevice;
		private static const PACKET_SIZE:int = 2000;
		private var baImage:ByteArray = new ByteArray();
		private var usrDir:File = File.userDirectory;
		private var _load:Loader = new Loader();
		private var decode:Base64Decoder = new Base64Decoder();
		private var webSocket:WebSocket;
		
		private var srcPort:int;
		private var srcAddress:String;

		public function ScreenshotServer(){
			_datagramSocket = new DatagramSocket();
		}
		
		// ScreenShotServerManager.register(device, port)
		// WebServerManager.register(device); -> associate web server whith device ID. Device get port ? Or server ?
		
		public function bind(/*ip:String, device:AndroidDevice, */port:int):int
		{
			// this.currentDevice = device;
			if(_datagramSocket.bound) 
			{
				_datagramSocket.close();
				_datagramSocket = new DatagramSocket();
			}
			_datagramSocket.bind();
			_datagramSocket.addEventListener(DatagramSocketDataEvent.DATA, dataReceived);
			_datagramSocket.addEventListener(IOErrorEvent.IO_ERROR, errorSocket);
			_datagramSocket.receive();
			
			webSocket = new WebSocket("ws://localhost:" + port.toString(), "*");
			webSocket.addEventListener(WebSocketEvent.OPEN, webSocketOpenHandler);
			webSocket.addEventListener(WebSocketEvent.MESSAGE, webSocketOnMessageHandler);
			webSocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, webSocketConnectionFailHandler);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			
			return _datagramSocket.localPort;
		}
		
		private function dataReceived(event:DatagramSocketDataEvent):void
		{
			srcAddress = event.srcAddress;
			srcPort = event.srcPort;
			
			if (webSocket.connected) {
				webSocket.sendUTF("ok");
			} else {
				webSocket.connect();
			}
		}
		
		private function errorSocket(event:IOErrorEvent):void
		{
			var error:String = event.text;
		}
		
		private function webSocketOnMessageHandler(event:WebSocketEvent):void
		{
			if (event.message.type === WebSocketMessage.TYPE_BINARY) {
				var buffer:ByteArray = event.message.binaryData
				
				try {
					var dataLength:int = buffer.length;
					var packetSize:int = PACKET_SIZE;
					var currentPos:int = 0;
					
					sendData(buffer, currentPos, dataLength, packetSize);
										
					while (dataLength > 0) {
						currentPos += packetSize;
						dataLength -= packetSize;
						if (dataLength < packetSize) {
							packetSize = dataLength;
						}
						sendData(buffer, currentPos, dataLength, packetSize);
					}
				} catch ( error:Error ){
					var errorStr:String = error.message;
				}
			}
		}
		
		public function sendData(screen:ByteArray, currentPos:int, dataLength:int, packetSize:int):void {
			var buffer: ByteArray = new ByteArray();
			buffer.writeInt(currentPos);
			buffer.writeInt(dataLength);
			
			if (dataLength > 0) {
				buffer.writeBytes(screen, currentPos, packetSize);
			}
						
			try {
				_datagramSocket.send(buffer, 0, buffer.length, srcAddress, srcPort);
			} catch ( error:Error ){
				var errorStr:String = error.message;
			}	
		}
		
		private function webSocketConnectionFailHandler(event:WebSocketErrorEvent):void 
		{
			trace("WebSocket ERROR : " + event.text);
		}
		
		private function webSocketOpenHandler(event:WebSocketEvent):void 
		{
			trace("Connected to websocket");
			webSocket.sendUTF("ok");
		}
		
		/*public function getImage(ev:Event):void {
			var file:File = File.userDirectory.resolvePath("screenCapture.png");
			var outFile:File = File.userDirectory;
			outFile = outFile.resolvePath(file.url);
			
			if(!file.exists) return;
			
			var fileStream:FileStream = new FileStream(); 
			fileStream.open(outFile, FileMode.READ);
			var bytes:ByteArray = new ByteArray
			fileStream.readBytes(bytes);
			fileStream.close();
			
			_load.contentLoaderInfo.addEventListener( Event.COMPLETE, loadbytesComplete);
			_load.loadBytes(bytes);
		}*/
		
		private function loadbytesComplete( event:Event ):void {
			var bit:Bitmap = _load.content as Bitmap;
			var newBmd:BitmapData = new BitmapData(bit.width,bit.height,true,0xFFFFFFFF);
			var rect:Rectangle = new Rectangle(0,0,bit.width,bit.height);
			
			bit.bitmapData.drawWithQuality(newBmd,null,null,null,null,false,StageQuality.MEDIUM);
			
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
		
		public function sendBackData(ev:Event):void
		{
			currentDevice.androidUsbScreenshot.removeEventListener(AndroidProcess.SCREENSHOTRESPONSE, sendBackData);
			decode.decode(currentDevice.androidUsbScreenshot.getResponse());
			var ba:ByteArray = decode.toByteArray();
			
			var dataLength:int = ba.length;
			
			var packetSize:int = PACKET_SIZE;
			var currentPos:int = 0;
			
			sendData(ba, 0, ba.length, PACKET_SIZE);
			
			while (dataLength > 0) {
				currentPos += packetSize;
				dataLength -= packetSize;
				if (dataLength < packetSize) {
					packetSize = dataLength;
				}
				sendData(ba, currentPos, dataLength, packetSize);
			}
			
			/*if(currentDevice.androidUsb.getResponse().toLocaleLowerCase().indexOf("error") == -1) {
				var data:Array = new Array();
				data.push("pull", currentDevice.androidUsb.getResponse(), "screenCapture.png");
				currentDevice.androidUsb.addEventListener(AndroidProcess.SCREENSHOTRESPONSE, getImage, false, 0, true);
				
				currentDevice.actionsInsertAt(0, new UsbAction(data));
				var usbAction:UsbAction = currentDevice.actionsShift();
				currentDevice.androidUsb.start(usbAction, false);
			}
			var ba:ByteArray = new ByteArray();
			ba.writeUTF(currentDevice.androidUsb.getResponse());
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
			
			var ba:ByteArray = new ByteArray();
			ba.writeUTFBytes(currentDevice.androidUsb.getResponse());
			var newBmd:BitmapData;
			
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.INIT, function(e:Event):void {
			newBmd.drawWithQuality(loader,null,null,null,null,false,StageQuality.MEDIUM);   
			var rect1:Rectangle = new Rectangle(0,0,newBmd.width,newBmd.height);
			//Send a datagram to the target
			try
			{
			var data:ByteArray = newBmd.getPixels(rect1);
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
			});
			loader.loadBytes(ba);*/
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void {
			trace("ioErrorHandler: " + event);
		}
	}
}