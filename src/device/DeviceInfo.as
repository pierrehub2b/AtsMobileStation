package device
{
	[RemoteClass(alias="worker.DeviceInfo")]
	public class DeviceInfo
	{
		public var manufacturer:String = "";
		public var modelId:String = "";
		public var modelName:String = "";
		public var androidVersion:String = "";
		public var androidSdk:String = "";
		
		public function checkName():void{
			if(modelName == ""){
				modelName = modelId;
			}
		}
	}
}