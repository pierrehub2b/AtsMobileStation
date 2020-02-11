package webServer
{
	import device.Device;
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	
	import flash.events.Event;
	import flash.events.OutputProgressEvent;
	import flash.events.ProgressEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.clearInterval;
	import flash.utils.setInterval;
	
	import usb.UsbAction;
	
	import webServer.mimetype.MimeType;
	
	/**
	 * This is a simple WebServer implementation in AS3. It can only however stream videos properly to
	 * Safari browsers (desktop and mobile)
	 *  
	 * @author mikkohaapoja
	 * 
	 */	
	public class WebServer
	{	
		private static const MAX_PACKET:int=1048576;
		private var server:ServerSocket;
		private var mimeType:MimeType;
		
		private var returnData:ByteArray;
		private var returnPos:int;
		
		private var rex:RegExp = /[\s\r\n]+/gim;
		private var currentDevice:AndroidDevice;
		private var errorCallback:Function = null;
		private var socket:Socket;
				
		/**
		 * This is a simple WebServer implementation in AS3. It can only however stream videos properly to
		 * Safari browsers (desktop and mobile) 
		 */		
		public function WebServer(device:AndroidDevice)
		{
			this.currentDevice = device
			this.mimeType=new MimeType(["html", "htm", "png", "jpg", "jpeg", "png", "gif", "mp4"]);
		}
		
		public function initServerSocket(port:int, automaticPort:Boolean, errorCallback:Function):String {
			try {
				server=new ServerSocket();
				server.addEventListener(ServerSocketConnectEvent.CONNECT, onConnect);
				
				server.bind(port);
				server.listen();

				return port.toString();
			} catch (error:Error) {
				if(automaticPort) {
					return initServerSocket(port+1,automaticPort,errorCallback);
				} else {
					errorCallback("Port "+ port +" is in use. Retrying...");
					if(server.bound) {
						server.close();
					}
				}
			}
			return port.toString();
		}
		
		/**
		 * You can setup which mimetypes the server will support.
		 *  
		 * @param mimeTypes This is contain which mimetypes this server will support
		 * 
		 */		
		public function setMimeTypes(mimeTypes:MimeType):void
		{
			this.mimeType=mimeTypes;
		}
		
		/**
		 * This function will close and kill the web server. 
		 * 
		 */		
		public function close():void
		{
			if(server.localPort != 0) {
				server.close();
			}
			
		}
		
		private function onConnect(ev:ServerSocketConnectEvent):void
		{
			var socket:Socket=ev.socket;
			
			socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketSendData);
			socket.addEventListener(Event.CLOSE, onSocketClose);
		}
		
		private function onSocketSendData(ev:ProgressEvent):void
		{
			socket=Socket(ev.target);
			var headerData:ByteArray=new ByteArray();
			socket.readBytes(headerData);
			
			var header:String=headerData.toString();
			
			var headerSplit:Array=header.split("\n").join(": ").split(": ");
			
			headerSplit.length-=2; //-2 for the last \n\n chars
			
			var headerObj:Object={};
			var numHeader:int=(headerSplit.length-1)/2;
			
			for(var i:int=0;i<numHeader;i++) 
			{
				var keyIdx:int=i*2+1;
				var valueIdx:int=i*2+2;
				
				headerObj[headerSplit[keyIdx]]=headerSplit[valueIdx];
			}
			
			var requestType:String =headerSplit[0].substring(0, header.indexOf(" "));		
			var connection:String=headerObj["Connection"];
		
			//GET, HEAD, POST, PUT, DELETE, OPTIONS, TRACE, CONNECT
			switch(requestType)
			{
				case "POST":
					var splittedHeader:Array = headerSplit[0].split(" ");
					var url:String = splittedHeader[1].substring(1, splittedHeader[1].length);
					
					var requestData:Array = header.split("\n");
					var data:Array = new Array();
					data.push("dumpsys", "activity", AndroidProcess.ANDROIDDRIVER);
					data.push(url);
					if(url == "screenshot") {
						data.push("hires");
						currentDevice.androidUsbAction.addEventListener(AndroidProcess.USBACTIONRESPONSE, usbActionScreenshotResponseEnded, false, 0, true);
					} else {
						currentDevice.androidUsbAction.addEventListener(AndroidProcess.USBACTIONRESPONSE, usbActionResponseEnded, false, 0, true);
						var isData:Boolean = false;
						for(var j:int=0;j<requestData.length;j++){
							if(isData) {
								data.push(requestData[j]);
							}
							if(requestData[j] == "\r") {
								isData = true;
							}
						}					
						
						if(url == "driver" && data[4] == "start") {
							if(currentDevice.usbMode) {
								currentDevice.androidUsbAction.addEventListener(AndroidProcess.USBSTARTRESPONSE, usbStartResponseEnded, false, 0, true);
								data.push(AndroidDevice.UDPSERVER.toString().toLocaleLowerCase());
								AndroidDevice.UDPSERVER ? data.push(currentDevice.udpIpAdresse) : data.push(currentDevice.ip, currentDevice.startScreenshotServer().toString());
							}
						}
						
						if(url == "app" && data[4] == "start") {
							var startData:Array = new Array();
							startData.push("dumpsys", "activity", AndroidProcess.ANDROIDDRIVER, "package", data[5]);
							currentDevice.actionsPush(new UsbAction(startData));
						}
						
						if((url == "driver" || url == "app") && data[4] == "stop") {
							var stopData:Array = new Array();
							stopData.push("am", "force-stop", AndroidProcess.ANDROIDDRIVER);
							currentDevice.actionsPush(new UsbAction(stopData));
							currentDevice.stopScreenshotServer();
						}
					}
					
					currentDevice.actionsPush(new UsbAction(data));
					onActionQueueChanged();
					
					break;
				default:
					trace("OH NO DEFINE |"+requestType+"|");
					break;
			}
		}
		
		private function onSocketClose(ev:Event):void
		{
			var socket:Socket=Socket(ev.target);
			server.close();
		}
		
		private function usbStartResponseEnded(ev:Event):void {
			currentDevice.androidUsbAction.removeEventListener(AndroidProcess.USBSTARTRESPONSE, usbStartResponseEnded);
			currentDevice.androidUsbAction.addEventListener(AndroidProcess.USBSTARTENDEDRESPONSE, usbStartEndedResponseEnded, false, 0, true);
			
			var ActivityName:String = currentDevice.androidUsbAction.getResponse();
			var startData:Array = new Array();
			startData.push("am", "start", "-W", "-S","--activity-brought-to-front", 
				"--activity-multiple-task", "--activity-no-animation", "--activity-no-history", "-n", ActivityName);
			currentDevice.actionsInsertAt(0, new UsbAction(startData));
			onActionQueueChanged(true);
		}
		
		private function usbActionResponseEnded(ev:Event):void {
			if(currentDevice.androidUsbAction.getResponse() != "") {
				get(socket, currentDevice.androidUsbAction.getResponse(), "application/json");
			}
			currentDevice.androidUsbAction.removeEventListener(AndroidProcess.USBACTIONRESPONSE, usbActionResponseEnded);
		}
		
		private function usbActionScreenshotResponseEnded(ev:Event):void {
			if(currentDevice.androidUsbAction.getResponse() != "") {
				get(socket, currentDevice.androidUsbAction.getResponse(), "application/octet-stream", new Array());
			}
			currentDevice.androidUsbAction.removeEventListener(AndroidProcess.USBACTIONRESPONSE, usbActionScreenshotResponseEnded);
		}
		
		private function usbStartEndedResponseEnded(ev:Event):void {
			currentDevice.androidUsbAction.removeEventListener(AndroidProcess.USBACTIONRESPONSE, usbStartEndedResponseEnded);
			onActionQueueChanged();
		}
		
		private function onActionQueueChanged(startCommand:Boolean = false):void {
			var usbAction:UsbAction = currentDevice.actionsShift();
			currentDevice.androidUsbAction.requestAction(usbAction, startCommand);
		}
		
		private function get(socket:Socket, data:String, fileExtension:String, range:Array=null):void
		{		
			var returnHeader:String;
			returnData=new ByteArray();
			returnData.writeUTFBytes(data);
			
			returnHeader="HTTP/1.1 200 OK\r\n";
			returnHeader+="Server: AtsDroid Driver\r\n";
			returnHeader+="Date:"+new Date()+"\r\n";
			returnHeader+="Content-Type: "+fileExtension+"\r\n";
			returnHeader+="Content-Length: "+returnData.length+"\r\n\r\n";
			
			/*var returnHeaderBytes:ByteArray = new ByteArray();
			returnHeaderBytes.writeUTFBytes(returnHeader);
			
			socket.writeBytes(returnHeaderBytes,0,returnHeaderBytes.length);
			socket.writeBytes(returnData,0,returnData.length);*/
			socket.writeUTF(returnHeader);
			socket.writeUTF(data);
			socket.flush();
			socket.close();
			
		}
	}
}