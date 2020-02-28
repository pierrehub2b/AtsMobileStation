package events
{
	import flash.events.Event;
	
	import device.simulator.IosSimulator;
	
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