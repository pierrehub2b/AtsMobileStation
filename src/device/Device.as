package device
{
	import flash.events.EventDispatcher;

	public class Device extends EventDispatcher
	{
		public static const INSTALL:String = "install";
		public static const START:String = "start";
		public static const READY:String = "ready";
		public static const FAIL:String = "fail";
		
		[Bindable]
		public var id:String;
		
		[Bindable]
		public var status:String = START;
				
		[Bindable]
		public var ip:String;
		
		[Bindable]
		public var error:String = null;
		
		[Bindable]
		public var manufacturer:String = "";
		
		[Bindable]
		public var modelId:String = "";
		
		[Bindable]
		public var modelName:String = "";
				
		[Bindable]
		public var tooltip:String = "Starting driver ...";
		
		private var _connected:Boolean;
				
		public function get connected():Boolean
		{
			return _connected;
		}

		public function set connected(value:Boolean):void
		{
			_connected = value;
		}

		public function dispose():Boolean{
			return true;
		}
	}
}