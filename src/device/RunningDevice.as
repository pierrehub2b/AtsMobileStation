package device
{
	import avmplus.getQualifiedClassName;

	public class RunningDevice extends Device
	{
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
		public var errorMessage:String = "";
				
		[Bindable]
		public var simulator:Boolean = false;
		
		public function RunningDevice(id:String=""){
			super(id);
			tooltip = "Starting driver ..."
			trace("Starting driver -> " + getQualifiedClassName(this));
		}
		
		public function start():void{}
	
		protected function installing():void{
			status = INSTALL;
			tooltip = "Installing driver ...";
			trace("Installing driver -> " + getQualifiedClassName(this));
		}
		
		protected function started():void{
			status = READY
			tooltip = "Driver started and ready";
			trace("Driver started -> " + getQualifiedClassName(this));
		}
		
		protected function failed():void{
			status = FAIL
			tooltip = "Driver can not be started";
			trace("Driver error" + getQualifiedClassName(this));
		}
	}
}