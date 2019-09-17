package simulator
{
	import flash.events.EventDispatcher;

	public class Simulator extends EventDispatcher
	{
		public static const STATUS_CHANGED:String = "statusChanged";
		
		public static const OFF:String = "off";
		public static const WAIT:String = "wait";
		public static const RUN:String = "run";
		
		public var id:String;
		
		[Bindable]
		public var name:String;
		
		[Bindable]
		public var version:String;
		
		[Bindable]
		public var phase:String = OFF;
		
		[Bindable]
		public var tooltip:String = "Start simulator";
		
		[Bindable]
		public var isSimulator:Boolean = true;
		
		public function startStop():void{
			
		}
	}
}