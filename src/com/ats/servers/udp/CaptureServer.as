package com.ats.servers.udp
{
import com.worlize.websocket.WebSocket;
import com.worlize.websocket.WebSocketErrorEvent;
import com.worlize.websocket.WebSocketEvent;
import com.worlize.websocket.WebSocketMessage;

import flash.events.DatagramSocketDataEvent;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IOErrorEvent;
import flash.net.DatagramSocket;
import flash.utils.ByteArray;

public class CaptureServer extends EventDispatcher
	{
		public static const CAPTURE_SERVER_INITIALIZED:String = "captureServerInitialized";
		public static const CAPTURE_SERVER_STARTED:String = "captureServerStarted";
		public static const CAPTURE_SERVER_ERROR:String = "captureServerError";

		private static const PACKET_SIZE:int = 2000;
		
		private var datagramSocket:DatagramSocket = new DatagramSocket();
		private var webSocket:WebSocket;
		
		private var srcPort:int;
		private var srcAddress:String;

		public function CaptureServer() {}

		public function bind():void
		{
			try {
				datagramSocket.bind();

				datagramSocket.addEventListener(DatagramSocketDataEvent.DATA, dataReceived);
				datagramSocket.addEventListener(IOErrorEvent.IO_ERROR, errorSocket);

				dispatchEvent(new Event(CAPTURE_SERVER_INITIALIZED));
			} catch (e:Error) {
				dispatchEvent(new Event(CAPTURE_SERVER_ERROR));
			}
		}

		public function getLocalPort():int
		{
			return datagramSocket.localPort;
		}
		
		public function close():void
		{
			if (datagramSocket.bound) {
				datagramSocket.close();
			}
			
			if (webSocket != null && webSocket.connected) {
				webSocket.close(false);
			}
		}
		
		public function setupWebSocket(port:int):void
		{
			webSocket = new WebSocket("ws://localhost:" + port.toString(), "*");
			webSocket.addEventListener(WebSocketEvent.OPEN, webSocketOpenHandler);
			webSocket.addEventListener(WebSocketEvent.MESSAGE, webSocketOnMessageHandler);
			webSocket.addEventListener(WebSocketEvent.CLOSED, webSocketOnCloseHandler, false, 0, true);
			webSocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, webSocketConnectionFailHandler);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);

			datagramSocket.receive();

			dispatchEvent(new Event(CaptureServer.CAPTURE_SERVER_STARTED));
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

		private function webSocketOnCloseHandler(event:WebSocketEvent):void {
			webSocket.removeEventListener(WebSocketEvent.MESSAGE, webSocketOnMessageHandler);
			webSocket.removeEventListener(WebSocketEvent.CLOSED, webSocketOnCloseHandler);
			webSocket.removeEventListener(WebSocketErrorEvent.CONNECTION_FAIL, webSocketConnectionFailHandler);
			webSocket.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
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