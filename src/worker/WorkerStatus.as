package worker
{
	public final class WorkerStatus
	{
		public static const START_DRIVER:String = "startDriver"
			
		public static const RUNNING:String = "running"
		public static const STARTING:String = "starting"
		public static const STOPPED:String = "stopped"
		public static const INSTALL:String = "install"
			
		public static const INPUT_CHANNEL:String = "inputChannel"
		public static const OUTPUT_CHANNEL:String = "outputChannel"
			
		public static const LAN_ERROR:String = "lanError"
		public static const EXECUTE_ERROR:String = "executeError"
		public static const DEVICE_INFO:String = "deviceInfo"
		public static const IP_ADDRESS:String = "ipAddress"
	}
}