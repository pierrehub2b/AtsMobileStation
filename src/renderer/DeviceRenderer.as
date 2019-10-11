package renderer
{
	import flash.events.Event;
	
	import spark.components.supportClasses.ItemRenderer;
	
	import device.Device;
	
	public class DeviceRenderer extends ItemRenderer
	{
		public function DeviceRenderer()
		{
			super();
			autoDrawBackground = true;
			height = 40;
		}
		
		override public function set data(value:Object):void
		{
			if(super.data == null || super.data != value){
				super.data = value;
				dispatchEvent(new Event("updateDataEvent"))
			}
		}
			
		[Bindable(event="updateDataEvent")]
		public function get dev():Device{
			return data as Device
		}
		
		
		
		override protected function get hovered():Boolean { return false; }
		override public function get selected():Boolean { return false; }
	}
}