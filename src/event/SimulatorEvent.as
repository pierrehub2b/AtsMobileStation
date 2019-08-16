package event
{
	import simulator.IosSimulator;
	
	import flash.events.Event;
	
	public class SimulatorEvent extends Event
	{
		public var simulator:IosSimulator;
		
		public function SimulatorEvent(type:String, simulator:IosSimulator)
		{
			this.simulator = simulator;
			super(type, false, false);
		}
	}
}