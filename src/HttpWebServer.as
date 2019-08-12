package
{
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.utils.ByteArray;
	
	public class HttpWebServer
	{
		private var serverSocket:ServerSocket;
		private var port:int = 9090;
		
		private var postLoader:URLLoader;
		private var clientSocket:Socket;
		
		private var urlRegexp:RegExp = /POST (.*) HTTP.*/;
		
		public function HttpWebServer()
		{
			try
			{
				serverSocket = new ServerSocket();
				serverSocket.addEventListener(Event.CONNECT, socketConnectHandler);
				serverSocket.bind(port);
				serverSocket.listen();
			}
			catch (error:Error)
			{
			}
		}
		
		private function socketConnectHandler(event:ServerSocketConnectEvent):void
		{
			var socket:Socket = event.socket;
			socket.addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
		}
		
		private function socketDataHandler(event:ProgressEvent):void
		{
			try
			{
				clientSocket = event.target as Socket;
				var postRequest:String = clientSocket.readUTFBytes(clientSocket.bytesAvailable).replace(/\r/g, "");
				
				if(postRequest.indexOf("GET") == 0){
					sendReply("200", "text/html", "<html><body>AtsMobileStation ready</body></html>");
				}else{
					
					var url:Array = urlRegexp.exec(postRequest);
					if(url != null && url.length > 1){
						
						var request:URLRequest = new URLRequest("http://192.168.0.6:8080" + url[1]);
						request.contentType = "multipart/form-data";
						request.method = URLRequestMethod.POST;
						
						var postData:Array = postRequest.split(/\n\n/);
						if(postData.length > 1){
							request.data = postData[1];
						}
						
						postLoader = new URLLoader();
						postLoader.dataFormat = URLLoaderDataFormat.TEXT;
						postLoader.addEventListener(Event.COMPLETE, loaderCompleteHandler);
						postLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
						postLoader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
						
						postLoader.load(request);
						
					}else{
						sendReply("500", "text/html", "<html><body>Error sending post data</body></html>");
					}
				}
			}
			catch (error:Error)
			{
				
			}
		}
		
		private function sendReply(code:String, type:String, data:String):void{
			clientSocket.writeUTFBytes("HTTP/1.1 " + code + "\n");
			clientSocket.writeUTFBytes("Content-Type: " + type + "\n\n");
			clientSocket.writeUTFBytes(data);
			clientSocket.flush();
			clientSocket.close();
		}
		
		private function loaderCompleteHandler(e:Event):void {
			sendReply("200", "application/json", e.target.data);
		}
		
		private function securityErrorHandler( e:SecurityErrorEvent ):void {
			sendReply("500", "text/html", "Security error -> " + e.text);
		}
		
		private function ioErrorHandler( e:IOErrorEvent ):void {
			sendReply("500", "text/html", "IO error -> " + e.text);
		}
	}
}