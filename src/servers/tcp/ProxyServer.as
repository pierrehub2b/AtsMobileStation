package servers.tcp
{
import com.worlize.websocket.WebSocket;
import com.worlize.websocket.WebSocketConfig;
import com.worlize.websocket.WebSocketErrorEvent;
import com.worlize.websocket.WebSocketEvent;

import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IOErrorEvent;
import flash.events.OutputProgressEvent;
import flash.events.ProgressEvent;
import flash.events.ServerSocketConnectEvent;
import flash.net.ServerSocket;
import flash.net.Socket;
import flash.utils.ByteArray;

public class ProxyServer extends EventDispatcher
	{
		public static const WEB_SERVER_INITIALIZED:String = "webServerInitialized";
		public static const WEB_SERVER_STARTED:String = "webServerStarted";
		public static const WEB_SERVER_ERROR:String = "webServerError";

		private var serverSocket:ServerSocket = new ServerSocket();
		private var webSocket:WebSocket;
		private var count:int = 0

		private var proxySockets:Vector.<ProxySocket> = new Vector.<ProxySocket>();

		public function close():void 
		{
			if (webSocket != null) {
				webSocket.close(false);
			}
			
			if (serverSocket.bound) {
				serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT, onConnect);
				serverSocket.removeEventListener(Event.CLOSE, onClose);

				try {
					serverSocket.close();
				} catch (e:Error){
					trace("Erreur close server : " + e.message);
				}
			}
		}

		public function getLocalPort():int
		{
			return serverSocket.localPort;
		}
		
		public function ProxyServer():void {}
		
		public function bind(port:int):void
		{						
			try {
				serverSocket.bind(port);
				serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onConnect, false, 0, true);
				serverSocket.addEventListener(Event.CLOSE, onClose, false, 0, true);

				dispatchEvent(new Event(ProxyServer.WEB_SERVER_INITIALIZED));
			} catch (e: Error) {
				dispatchEvent(new Event(ProxyServer.WEB_SERVER_ERROR));
			}
		}

		public function setupWebSocket(port:int):void {
			webSocket = new WebSocket("ws://localhost:" + port.toString(), "*");
			var webSocketConfig:WebSocketConfig = new WebSocketConfig();
			webSocketConfig.maxReceivedFrameSize = 0x600000;
			webSocket.config = webSocketConfig;

			webSocket.addEventListener(WebSocketEvent.OPEN, webSocketOpenHandler, false, 0, true);
			webSocket.addEventListener(WebSocketEvent.MESSAGE, webSocketOnMessageHandler, false, 0, true);
			webSocket.addEventListener(WebSocketEvent.CLOSED, webSocketOnCloseHandler, false, 0, true);
			webSocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, webSocketConnectionFailHandler, false, 0, true);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler, false, 0, true);

			serverSocket.listen();

			dispatchEvent(new Event(ProxyServer.WEB_SERVER_STARTED));
		}
		
		private function onClose(e:Event):void {
			trace("close connection");
		}
		
		private function webSocketOnCloseHandler(event:WebSocketEvent):void {
			webSocket.removeEventListener(WebSocketEvent.MESSAGE, webSocketOnMessageHandler);
			webSocket.removeEventListener(WebSocketEvent.CLOSED, webSocketOnCloseHandler);
			webSocket.removeEventListener(WebSocketErrorEvent.CONNECTION_FAIL, webSocketConnectionFailHandler);
			webSocket.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		}
			
		private function webSocketOnMessageHandler(event:WebSocketEvent):void
		{
			var buffer:ByteArray = event.message.binaryData;

			var socketID:int = buffer.readInt();
			var socket:Socket = fetchSocket(socketID);
			if (socket != null) {
				socket.writeBytes(buffer, 4, buffer.length - 4);
				socket.flush();
			}
		}

		private function webSocketConnectionFailHandler(event:WebSocketErrorEvent):void 
		{
			trace("WebSocket ERROR : " + event.text);
		}
		
		private function webSocketOpenHandler(event:WebSocketEvent):void 
		{
			webSocket.removeEventListener(WebSocketEvent.OPEN, webSocketOpenHandler);

			for each(var proxySocket:ProxySocket in proxySockets) {
				webSocket.sendBytes(proxySocket.data);
			}
		}
		
		private function onConnect(event:ServerSocketConnectEvent):void
		{
			var socket:Socket = event.socket;
			socket.addEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData, false, 0, true);
			socket.addEventListener(OutputProgressEvent.OUTPUT_PROGRESS, onClientSocketOutputProgress, false, 0, true);
			socket.addEventListener(Event.CLOSE, onSocketClose, false, 0, true);

			// create new
			var proxySocket:ProxySocket = new ProxySocket();
			proxySocket.socket = socket;
			proxySocket.id = count;
			count++;

			proxySockets.push(proxySocket);
		}
		
		// 1. get from client
		private function onClientSocketData(event:ProgressEvent):void 
		{
			var socket:Socket = event.target as Socket;
			var proxySocket:ProxySocket = fetchProxySocket(socket);
			// read data

			var clientData:ByteArray = new ByteArray();
			var tempData:ByteArray = new ByteArray();
			clientData.writeInt(proxySocket.id);
			socket.readBytes(tempData, 0, socket.bytesAvailable);

			clientData.writeBytes(tempData, 0, tempData.length);
			proxySocket.data = clientData;

			// forward data
			if (webSocket.connected) {
				webSocket.sendBytes(clientData);
			} else {
				webSocket.connect();
			}
		}

		private function onClientSocketOutputProgress(event:OutputProgressEvent):void
		{
			if (event.bytesPending == 0) {
				var socket:Socket = event.target as Socket;
				socket.close();

				removeProxySocket(socket);
			}
		}
						
		private function onSocketClose(ev:Event):void {
			var socket:Socket = ev.target as Socket;
			removeProxySocket(socket);
		}
				
		private function ioErrorHandler(event:IOErrorEvent):void
		{
			trace("ioErrorHandler: " + event);
		}

		/////

		private function fetchProxySocket(socket:Socket):ProxySocket
		{
			for each (var proxySocket:ProxySocket in proxySockets) {
				if (proxySocket.socket === socket) {
					return proxySocket;
				}
			}

			return null;
		}

		private function fetchSocket(socketID:int):Socket
		{
			for each (var proxySocket:ProxySocket in proxySockets) {
				if (proxySocket.id == socketID) {
					return proxySocket.socket;
				}
			}

			return null;
		}

		private function removeProxySocket(socket:Socket):void
		{
			socket.removeEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData);
			socket.removeEventListener(OutputProgressEvent.OUTPUT_PROGRESS, onClientSocketOutputProgress);
			socket.removeEventListener(Event.CLOSE, onSocketClose);

			var proxySocket:ProxySocket = fetchProxySocket(socket);
			if (proxySocket != null) {
				var index:int = proxySockets.indexOf(proxySocket);
				proxySockets.removeAt(index);
			}
		}
	}
}