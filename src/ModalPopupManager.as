package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObjectContainer;
	import flash.filters.BitmapFilterQuality;
	import flash.filters.BlurFilter;
	
	import mx.core.FlexBitmap;
	import mx.core.FlexSprite;
	import mx.core.UIComponent;
	
	import spark.components.Group;
	import spark.components.SkinnableContainer;
	import spark.primitives.BitmapImage;
	
	public class ModalPopupManager
	{
		//private static var popupsList:Array = [];
		private static var container:Group;
		private static var parent:Group;
		private static var blurredImage:BitmapImage;
		
		public static function addPopup(group:Group, pop:Group):void{
			//popupsList.push(pop);
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
			
			blurredImage.filters = [new BlurFilter(4, 4, BitmapFilterQuality.HIGH)];
			
			container.addElement(blurredImage);
			
			container.addElement(pop);
		}
		
		public static function removePopup(pop:Group):void{
			parent.visible = true;
			blurredImage.bitmapData.dispose();
			container.removeElement(blurredImage);
			
			(pop.parent as Group).removeElement(pop);
		}
		
		
	}
}