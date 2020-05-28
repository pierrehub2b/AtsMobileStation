package device
{
	import flash.events.Event;
	import flash.events.EventDispatcher;

	[Bindable]
	public class Device extends EventDispatcher
	{
		public static const STOPPED_EVENT:String = "deviceStopped";
		public static const WAITING_FOR_DEVICE:String = "waiting for device";
		public static const INSTALL:String = "install";
		public static const START:String = "start";
		public static const READY:String = "ready";
		public static const FAIL:String = "fail";
		public static const WIFI_ERROR:String = "wifiError";
		public static const USB_ERROR:String = "usbError";

		public var id:String = "";
		public var manufacturer:String = "";
		public var modelId:String = "";
		public var modelName:String = "";
		public var osVersion:String = "";
		public var sdkVersion:String = "";
		
		public var status:String = START;
		
		[Transient]
		public var tooltip:String;
		
		public function Device(id:String="")
		{
			this.id = id;
		}
		
		public function checkName():void{
			if(modelName == ""){
				modelName = modelId;
			}
		}
		
		public function dispose():Boolean{
			return true;
		}
		
		public function close():void{
			if(!dispose()){
				dispatchEvent(new Event(STOPPED_EVENT));
			}
		}
	}
}