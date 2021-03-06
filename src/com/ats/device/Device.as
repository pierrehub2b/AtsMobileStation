package com.ats.device
{
	import flash.events.Event;
	import flash.events.EventDispatcher;

	[Bindable]
	public class Device extends EventDispatcher
	{
		public static const STOPPED_EVENT:String = "deviceStopped";
		public static const INSTALL:String = "install";
		public static const INSTALL_APP:String = "installApp";
		public static const START:String = "start";
		public static const READY:String = "ready";
		public static const BOOT:String = "boot";
		public static const FAIL:String = "fail";
		public static const WIFI_ERROR:String = "wifiError";
		public static const USB_ERROR:String = "usbError";
		public static const ERROR:String = "error";

		public var id:String = "";
		public var manufacturer:String = "";
		public var modelId:String = "";
		protected var _modelName:String = "";
		public var osVersion:String = "";
		public var simulator:Boolean = false;

		public var status:String = START;
		
		[Transient]
		public var tooltip:String;
		
		public function Device(id:String="")
		{
			this.id = id;
		}

		public function dispose():Boolean{
			return true;
		}
		
		public function close():void{
			if(!dispose()){
				dispatchEvent(new Event(STOPPED_EVENT));
			}
		}

		public function get modelName():String {
			return _modelName;
		}

		public function set modelName(value:String):void {
			_modelName = value;
		}
	}
}