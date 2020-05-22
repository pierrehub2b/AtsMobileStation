package device
{
	import avmplus.getQualifiedClassName;

	[Bindable]
	public class RunningDevice extends Device
	{
		public var lockedBy:String = null;
		public var ip:String;
		public var port:String = "";
		public var settingsPort:String = "";
		public var automaticPort:Boolean = true;
		public var error:String = null;
		public var errorMessage:String = "";
		public var simulator:Boolean = false;
		public var usbMode:Boolean = false;
		public var udpIpAddress:String;
		
		public function RunningDevice(id:String=""){
			super(id);
			tooltip = "Starting driver ...";
			trace("Starting driver -> " + getQualifiedClassName(this));
		}
		
		public function start():void{}
	
		protected function installing():void{
			status = INSTALL;
			tooltip = "Installing driver ...";
			trace("Installing driver -> " + getQualifiedClassName(this));
		}
		
		protected function started():void{
			status = READY;
			tooltip = "Driver started and ready";
			trace("Driver started -> " + getQualifiedClassName(this));
		}
		
		protected function failed():void{
			status = FAIL;
			tooltip = "Driver can not be started";
			trace("Driver error" + getQualifiedClassName(this));
		}

		protected function usbError(error:String):void {
			status = USB_ERROR;
			errorMessage = " - " + error;
			tooltip = "Problem when installing driver ...";
			trace("USB install error" + getQualifiedClassName(this));
		}
	}
}