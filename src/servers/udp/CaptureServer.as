package servers.udp
{
import com.worlize.websocket.WebSocket;
import com.worlize.websocket.WebSocketErrorEvent;
import com.worlize.websocket.WebSocketEvent;
import com.worlize.websocket.WebSocketMessage;

import flash.events.DatagramSocketDataEvent;
import flash.events.IOErrorEvent;
import flash.net.DatagramSocket;
import flash.utils.ByteArray;

public class CaptureServer
	{
		private static const PACKET_SIZE:int = 2000;
		
		public var datagramSocket:DatagramSocket = new DatagramSocket();
		private var webSocket:WebSocket;
		
		private var srcPort:int;
		private var srcAddress:String;

		public function CaptureServer(){
			datagramSocket = new DatagramSocket();
		}
		
		public function close():void {
			if(datagramSocket.bound) {
				datagramSocket.close();
			}
			
			if (webSocket.connected) {
				webSocket.close(false);
			}
		}
		
		public function bind(port:int, devicePort:int):int
		{
			if(datagramSocket.bound) {
				datagramSocket.close();
			}

			datagramSocket = new DatagramSocket();
			datagramSocket.bind(port);
			datagramSocket.addEventListener(DatagramSocketDataEvent.DATA, dataReceived);
			datagramSocket.addEventListener(IOErrorEvent.IO_ERROR, errorSocket);
			datagramSocket.receive();
			
			webSocket = new WebSocket("ws://localhost:" + devicePort.toString(), "*");
			webSocket.addEventListener(WebSocketEvent.OPEN, webSocketOpenHandler);
			webSocket.addEventListener(WebSocketEvent.MESSAGE, webSocketOnMessageHandler);
			webSocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, webSocketConnectionFailHandler);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			
			return datagramSocket.localPort;
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
				var buffer:ByteArray = event.message.binaryData;
				
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
				datagramSocket.send(buffer, 0, buffer.length, srcAddress, srcPort);
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
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			trace("ioErrorHandler: " + event);
		}
	}
}