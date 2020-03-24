package servers.tcp
{
	import com.worlize.websocket.WebSocket;
	import com.worlize.websocket.WebSocketErrorEvent;
	import com.worlize.websocket.WebSocketEvent;
	import com.worlize.websocket.WebSocketMessage;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	
	public class WebServer
	{	
		private var serverSocket:ServerSocket = new ServerSocket();
		private var activeSocket:Socket;
		private var clientData:ByteArray;
		private var webSocket:WebSocket;
							
		public function getPort():int 
		{
			return serverSocket.localPort;
		}
				
		public function close():void 
		{					
			webSocket.close(false);
			
			closeSocket();
			
			if (serverSocket.bound) {
				try {
					serverSocket.close();
					serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT, onConnect);
					serverSocket.removeEventListener(Event.CLOSE, onClose);
				} catch (e:Error){
					trace("Erreur close server : " + e.message);
				}
			}
		}
		
		public function WebServer(port:int, devicePort:int):void {
			setup(port, devicePort);
		}
		
		public function setup(port:int, devicePort:int):void 
		{						
			try {
				serverSocket.bind(port);
				serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onConnect, false, 0, true);
				serverSocket.addEventListener(Event.CLOSE, onClose, false, 0, true);
				serverSocket.listen();	
				trace(serverSocket.localPort);
				
				webSocket = new WebSocket("ws://localhost:" + devicePort.toString(), "*");
				webSocket.addEventListener(WebSocketEvent.OPEN, webSocketOpenHandler, false, 0, true);
				webSocket.addEventListener(WebSocketEvent.MESSAGE, webSocketOnMessageHandler, false, 0, true);
				webSocket.addEventListener(WebSocketEvent.CLOSED, webSocketOnCloseHandler, false, 0, true);
				webSocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, webSocketConnectionFailHandler, false, 0, true);
				webSocket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler, false, 0, true);
				
			} catch (e: Error) {
				trace("Erreur server socket init : " + e.message);
				setup(0, devicePort);
				// TODO return error if automaticPort == false
			}
			
		}
		
		private function onClose(e:Event):void {
			trace("close connection");
		}
		
		private function webSocketOnCloseHandler(event:WebSocketEvent):void {
			trace("webSocket closed");
			webSocket.removeEventListener(WebSocketEvent.MESSAGE, webSocketOnMessageHandler);
			webSocket.removeEventListener(WebSocketEvent.CLOSED, webSocketOnCloseHandler);
			webSocket.removeEventListener(WebSocketErrorEvent.CONNECTION_FAIL, webSocketConnectionFailHandler);
			webSocket.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		}
			
		private function webSocketOnMessageHandler(event:WebSocketEvent):void
		{
			if (event.message.type === WebSocketMessage.TYPE_BINARY) {
				var buffer:ByteArray = event.message.binaryData;
				activeSocket.writeBytes(buffer, 0, buffer.length);
				activeSocket.flush();
				activeSocket.close();
			}
		}
		
		private function closeSocket():void {
			if (activeSocket != null) {
				activeSocket.removeEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData);
				activeSocket.removeEventListener(Event.CLOSE, onSocketClose);
				
				if (activeSocket.connected) {
					activeSocket.close();
				}
				
				activeSocket = null;
			}
		}
		
		private function webSocketConnectionFailHandler(event:WebSocketErrorEvent):void 
		{
			trace("WebSocket ERROR : " + event.text);
		}
		
		private function webSocketOpenHandler(event:WebSocketEvent):void 
		{
			webSocket.removeEventListener(WebSocketEvent.OPEN, webSocketOpenHandler);

			webSocket.sendBytes(clientData);
		}
		
		private function onConnect(event:ServerSocketConnectEvent):void
		{	
			if (activeSocket != null && activeSocket.connected) {
				
			} else {
				activeSocket = event.socket;
				activeSocket.addEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData, false, 0, true);
				activeSocket.addEventListener(Event.CLOSE, onSocketClose, false, 0, true);
			}
		}
		
		// 1. get from client
		private function onClientSocketData(event:ProgressEvent):void 
		{
			// read data
			clientData = new ByteArray();
			activeSocket.readBytes(clientData, 0, activeSocket.bytesAvailable);
						
			// forward data
			if (webSocket.connected == true) {
				webSocket.sendBytes(clientData);
			} else {
				webSocket.connect();
			}
		}
						
		private function onSocketClose(ev:Event):void {
			trace(ev);
		}
						
		private function closeHandler(event:Event):void {
			var serverSocket:ServerSocket = event.target as ServerSocket;
			serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT, onConnect);
			serverSocket.removeEventListener(Event.CLOSE, onClose);
		}
				
		private function ioErrorHandler(event:IOErrorEvent):void
		{
			trace("ioErrorHandler: " + event);
		}
				
		// TO.DO Anthony: A refactorer
		private static function getAvailablePort():int 
		{
			var server:ServerSocket = new ServerSocket();
			server.bind();
			server.listen();
			var availablePort:int = server.localPort;
			server.close();
			return availablePort;
		}
	}
}