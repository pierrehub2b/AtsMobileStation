package events
{
	import flash.events.Event;
	
	public class AndroidUsbChannelEvent extends Event
	{
		public static const BAD_COMMAND_ERROR:String = "badCommandError";
		
		public var message:String;
		
		public function AndroidUsbChannelEvent(type:String, message:String)
		{
			this.message = message;
			super(type, true, false);
		}
		
		public function get jsonData():String{
			var data:Object = {};
			data.type = type;
			data.message = message;
			
			return JSON.stringify(data);
		}
		
		override public function clone():Event
		{
			return new AndroidUsbChannelEvent(type, message);
		}
	}
}