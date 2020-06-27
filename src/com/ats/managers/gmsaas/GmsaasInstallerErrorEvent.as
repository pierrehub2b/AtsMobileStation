package com.ats.managers.gmsaas {
	import flash.events.Event;
	
	public class GmsaasInstallerErrorEvent extends Event {
		
		public static const ERROR:String = "GmsaasInstallerEventError"
		
		public var error:Error
		
		public function GmsaasInstallerErrorEvent(errorMessage:String) {
			super(ERROR);
			this.error = new Error(errorMessage)
		}
	}
}
