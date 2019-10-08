package worker
{
	[RemoteClass(alias="worker.WorkerError")]
	public class WorkerError
	{
		public var type:String;
		public var message:String;
		
		public function WorkerError(type:String=null, message:String=null)
		{
			this.type = type;
			this.message = message;
		}
	}
}