package device
{
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.system.WorkerDomain;
	import flash.system.WorkerState;
	import flash.utils.ByteArray;
	
	import worker.DeviceInfo;
	import worker.DeviceIp;
	import worker.WorkerError;
	import worker.WorkerStatus;
	
	public class AndroidDevice extends Device
	{
		private static const atsdroidFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		
		public var androidVersion:String = "";
		public var androidSdk:String = "";
		
		public var type:String;
		
		private var androidWorker:Worker;
		private var outputChannel:MessageChannel;
		
		[Embed(source="/AndroidWorker.swf", mimeType="application/octet-stream")]
		private var AndroidWorkerClass:Class;
		
		public function AndroidDevice(adbFile:File, port:String, id:String, type:String)
		{
			this.port = port;
			this.connected = true;
			this.id = id;
			this.type = type;
			
			androidWorker = WorkerDomain.current.createWorker(new AndroidWorkerClass(), true);
			
			outputChannel = androidWorker.createMessageChannel(Worker.current);
			outputChannel.addEventListener(Event.CHANNEL_MESSAGE, handleProgressMessage);
			
			androidWorker.setSharedProperty(WorkerStatus.OUTPUT_CHANNEL, outputChannel);
			androidWorker.setSharedProperty("atsdroidFilePath", atsdroidFilePath);
			androidWorker.setSharedProperty("port", port);
			androidWorker.setSharedProperty("id", id);
			androidWorker.setSharedProperty("adbFilePath", adbFile.nativePath);
			
			androidWorker.start();
		}
		
		private function handleProgressMessage(event:Event):void
		{
			var receivedData:* = outputChannel.receive();
			
			if(receivedData == WorkerStatus.STARTING){
				
				status = INSTALL;
				
			}else if(receivedData == WorkerStatus.RUNNING){
				
				status = READY
				tooltip = "Android " + androidVersion + ", API " + androidSdk + " [" + id + "]\nready and waiting testing actions"
			
			}else if(receivedData == WorkerStatus.STOPPED){
				
				terminate();
				dispatchEvent(new Event("deviceStopped"));
				
			}else if(receivedData is WorkerError){
				
				var error:WorkerError = receivedData as WorkerError;
				
				terminate();
				
				if(error.type == WorkerStatus.LAN_ERROR){
					//TODO show specific error to user
				}else if(error.type == WorkerStatus.EXECUTE_ERROR){
					//TODO show specific error to user
				}
				
				status = FAIL
				connected = false;
				
				dispatchEvent(new Event("deviceStopped"));
				
			}else if(receivedData is DeviceIp){
				
				ip = (receivedData as DeviceIp).ip
				
			}else if(receivedData is DeviceInfo){
				
				var deviceInfo:DeviceInfo = receivedData as DeviceInfo
				manufacturer = deviceInfo.manufacturer
				modelId = deviceInfo.modelId
				modelName = deviceInfo.modelName
				androidVersion = deviceInfo.androidVersion
				androidSdk = deviceInfo.androidSdk
			}
		}
		
		override public function dispose():Boolean{
			if(androidWorker.state == WorkerState.RUNNING){
				terminate();
				return true;
			}
			return false;
		}
		
		private function terminate():void{
			outputChannel.removeEventListener(Event.CHANNEL_MESSAGE, handleProgressMessage);
			outputChannel.close();
			androidWorker.terminate();
		}
	}
}