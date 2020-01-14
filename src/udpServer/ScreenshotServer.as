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
	
	public class ScreenshotServer extends Sprite
	{
		private var datagramSocket:ScreenshotServer = new ScreenshotServer();
		private var targetIP:String;
		private var targetPort:String;
		private var message:String;

		public function DatagramSocketExample()
		{
			ScreenshotServer();
		}
		
		private function bind( event:Event ):void
		{
			if( datagramSocket.bound ) 
			{
				datagramSocket.close();
				datagramSocket = new ScreenshotServer();
				
			}
			datagramSocket.bind( parseInt( localPort.text ), localIP.text );
			datagramSocket.addEventListener( DatagramSocketDataEvent.DATA, dataReceived );
			datagramSocket.receive();
			log( "Bound to: " + datagramSocket.localAddress + ":" + datagramSocket.localPort );
		}
		
		private function dataReceived( event:DatagramSocketDataEvent ):void
		{
			//Read the data from the datagram
			log("Received from " + event.srcAddress + ":" + event.srcPort + "> " + 
				event.data.readUTFBytes( event.data.bytesAvailable ) );
		}
		
		private function send( event:Event ):void
		{
			//Create a message in a ByteArray
			var data:ByteArray = new ByteArray();
			data.writeUTFBytes( message.text );
			
			//Send a datagram to the target
			try
			{
				datagramSocket.send( data, 0, 0, targetIP.text, parseInt( targetPort.text )); 
				log( "Sent message to " + targetIP.text + ":" + targetPort.text );
			}
			catch ( error:Error )
			{
				log( error.message );
			}
		}
		
		private function log( text:String ):void
		{
			logField.appendText( text + "\n" );
			logField.scrollV = logField.maxScrollV;
			trace( text );
		}
		
		private function ScreenshotServer(ipAdress:String, port:String):void
		{
			targetIP = ipAdress;
			targetPort = port;
			this.stage.nativeWindow.activate();
		}
		
		private function createTextField( x:int, y:int, label:String, defaultValue:String = '', editable:Boolean = true, height:int = 20 ):TextField
		{
			var labelField:TextField = new TextField();
			labelField.text = label;
			labelField.type = TextFieldType.DYNAMIC;
			labelField.width = 180;
			labelField.x = x;
			labelField.y = y;
			
			var input:TextField = new TextField();
			input.text = defaultValue;
			input.type = TextFieldType.INPUT;
			input.border = editable;
			input.selectable = editable;
			input.width = 280;
			input.height = height;
			input.x = x + labelField.width;
			input.y = y;
			
			this.addChild( labelField );
			this.addChild( input );
			
			return input;
		}
		
		private function createTextButton( x:int, y:int, label:String, clickHandler:Function ):TextField
		{
			var button:TextField = new TextField();
			button.htmlText = "<u><b>" + label + "</b></u>";
			button.type = TextFieldType.DYNAMIC;
			button.selectable = false;
			button.width = 180;
			button.x = x;
			button.y = y;
			button.addEventListener( MouseEvent.CLICK, clickHandler );
			
			this.addChild( button );
			return button;
			
		}
	}
}