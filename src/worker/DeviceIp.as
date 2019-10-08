package worker
{
	[RemoteClass(alias="worker.DeviceIp")]
	public class DeviceIp
	{
		public var ip:String;
		
		public function DeviceIp(ip:String=null)
		{
			this.ip = ip;
		}
	}
}