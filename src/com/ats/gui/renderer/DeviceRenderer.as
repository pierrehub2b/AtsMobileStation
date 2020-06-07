package com.ats.gui.renderer
{
	import spark.components.supportClasses.ItemRenderer;
	
	public class DeviceRenderer extends ItemRenderer
	{
		public function DeviceRenderer()
		{
			super();
			autoDrawBackground = true;
			height = 40;
		}
		
		override protected function get hovered():Boolean { return false; }
		override public function get selected():Boolean { return false; }
	}
}