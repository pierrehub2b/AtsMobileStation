package CustomClasses
{
	public class SimCtlDevice
	{
		private var availabilityError: String;
		private var isAvailable: Boolean;
		private var name: String;
		private var state: String;
		private var udid: String;
		
		public function SimCtlDevice(availabilityError: String, isAvailable: Boolean, name: String, state: String, udid: String)
		{
			this.availabilityError = availabilityError;
			this.isAvailable = isAvailable;
			this.name = name;
			this.state = state;
			this.udid = udid;
		}
		
		public function getAvailabilityError():String{
			return this.availabilityError;
		}
		
		public function getIsAvailable():Boolean{
			return this.isAvailable;
		}
		
		public function getName():String{
			return this.name;
		}
		
		public function getState():String{
			return this.state;
		}
		
		public function getUdid():String{
			return this.udid;
		}
	}
}