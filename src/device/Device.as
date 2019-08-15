package device
{
	import flash.events.EventDispatcher;

	public class Device extends EventDispatcher
	{
		[Bindable]
		public var id:String;
		
		public var connected:Boolean;
				
		public function dispose():Boolean{
			return true;
		}
	}
}