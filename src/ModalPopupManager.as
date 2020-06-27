package
{
	import com.greensock.TweenMax;
	
	import flash.display.BitmapData;
	
	import spark.components.Group;
	import spark.primitives.BitmapImage;
	
	public class ModalPopupManager
	{
		private static var container:Group;
		private static var parent:Group;
		private static var blurredImage:BitmapImage;
		
		public static function addPopup(group:Group, pop:Group):void{

			parent = group;
			container = group.parent as Group;
			
			pop.x = (group.width - pop.width) / 2
			pop.y = (group.height - pop.height) / 2
			
			var snapitBitmapData:BitmapData = new BitmapData(group.width, group.height, true, 0x000000);
			snapitBitmapData.draw(group, null, null, null, null, true);
			
			parent.visible = false;
			
			blurredImage = new BitmapImage();
			blurredImage.source = snapitBitmapData;
			blurredImage.x = group.x;
			blurredImage.y = group.y;
			blurredImage.alpha = 0.6
				
			TweenMax.set(blurredImage, {blurFilter:{blurX:4, blurY:4}, colorMatrixFilter:{colorize:0xffffff, amount:0.5, brightness:1.4, saturation:0.5}})
			
			container.addElement(blurredImage);
			container.addElement(pop);
		}
		
		public static function removePopup(pop:Group):void{
			parent.visible = true;
			blurredImage.bitmapData.dispose();
			
			container.removeElement(blurredImage);
			container.removeElement(pop);
		}
	}
}