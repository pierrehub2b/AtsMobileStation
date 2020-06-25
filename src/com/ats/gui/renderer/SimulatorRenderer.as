package com.ats.gui.renderer
{
	import com.ats.device.simulator.Simulator;
	
	import flash.display.GradientType;
	import flash.events.Event;
	import flash.geom.Matrix;
	
	import mx.events.ResizeEvent;
	
	import spark.components.supportClasses.ItemRenderer;
	
	public class SimulatorRenderer extends ItemRenderer
	{
		protected var matrix:Matrix = new Matrix();
		
		public function SimulatorRenderer()
		{
			super();
			addEventListener(ResizeEvent.RESIZE, resizeEventHandler);
			
			autoDrawBackground = false;
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
		public function get sim():Simulator{
			return data as Simulator
		}
		
		override public function set itemIndex(value:int):void
		{
			super.itemIndex = value;
		}
		
		private function resizeEventHandler(event:ResizeEvent):void{
			
			matrix.createGradientBox(width, height);
			matrix.rotate(78);
			
			graphics.clear();
			
			graphics.beginGradientFill(GradientType.LINEAR, [0x424c58, 0x373f4a], [1.0, 1.0], [0, 160], matrix);
			
			graphics.moveTo(6, 0);
			graphics.lineTo(width-6, 0);
			graphics.curveTo(width, 0, width, 6);
			
			graphics.lineTo(width, height)
			graphics.lineTo(0, height)
			graphics.lineTo(0, 6)
			
			graphics.curveTo(0, 0, 6, 0);
			
			graphics.endFill();
		}
		
		override protected function get hovered():Boolean { return false; }
		override public function get selected():Boolean { return false; }
	}
}