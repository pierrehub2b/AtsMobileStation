package device
{
	import flash.events.Event;
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
		public var ip:String;
		
		[Bindable]
		public var port:String = "";
		
		[Bindable]
		public var settingsPort:String = "";
		
		[Bindable]
		public var automaticPort:Boolean = true;
		
		[Bindable]
		public var error:String = null;
		
		[Bindable]
		public var manufacturer:String = "";
		
		[Bindable]
		public var modelId:String = "";
		
		[Bindable]
		public var modelName:String = "";
						
		[Bindable]
		public var status:String = START;
		
		[Bindable]
		public var tooltip:String = "Starting driver ...";
		
		public var isCrashed:Boolean = false;
		private var _connected:Boolean = false;
		public var isSimulator:Boolean = false;
				
		public function get connected():Boolean
		{
			return isSimulator || _connected;
		}

		public function set connected(value:Boolean):void
		{
			_connected = value;
		}
				
		protected function installing():void{
			status = INSTALL;
			tooltip = "Installing driver ...";
			trace("Install driver ...");
		}
		
		protected function started():void{
			status = READY
			tooltip = "Driver started and ready";
			trace("Driver started");
		}

		public function dispose():Boolean{
			return true;
		}
		
		public function close():void{
			if(!dispose()){
				_connected = false;
				dispatchEvent(new Event("deviceStopped"));
			}
		}
	}
}