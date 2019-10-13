package device.simulator
{
	import device.Device;

	public class Simulator extends Device
	{
		public static const OFF:String = "off";
		public static const RUNNING:String = "running";
		public static const SHUTDOWN:String = "shutdown";
		
		public function Simulator(id:String=""):void{
			super(id);
			statusOff();
		}
		
		public function statusOff():void{
			status = OFF;
			tooltip = "Start simulator";
		}
		
		public function statusOn():void{
			status = RUNNING;
			tooltip = "Shutdown simulator";
		}
		
		public function get started():Boolean{
			return status == RUNNING;
		}
		
		public function set started(value:Boolean):void{
			if(value){
				statusOn()
			}
		}
				
		public function startStop():void{
			if(status == OFF){
				status = START;
				tooltip = "Simulator is starting ...";
				startSim();
			} else if(status == RUNNING){
				status = SHUTDOWN;
				tooltip = "Simulator is terminating ...";
				stopSim();
			}
		}
		
		public function startSim():void{
			
		}
		
		public function stopSim():void{
			
		}
	}
}