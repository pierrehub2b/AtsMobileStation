package device
{
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.system.WorkerDomain;
	import flash.system.WorkerState;
	import flash.utils.ByteArray;
	
	import worker.WorkerStatus;
	
	public class AndroidDevice extends Device
	{
		private static const androidDriverFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
						
		public var androidVersion:String = "";
		public var androidSdk:String = "";

		public var type:String;
		
		private var androidWorker:Worker;
		private var inputChannel:MessageChannel;
		private var outputChannel:MessageChannel;
						
		[Embed(source="/AndroidWorker.swf", mimeType="application/octet-stream")]
		private var AndroidWorkerClass:Class;
		
		private var startDriverArgs:Array;
		
		public function AndroidDevice(adbFilePath:String, port:String, id:String, type:String)
		{
			this.port = port;
			this.connected = true;
			this.id = id;
			this.type = type;
			
			this.startDriverArgs = ["startDriver", androidDriverFilePath, port, id, adbFilePath];
			
			androidWorker = WorkerDomain.current.createWorker(new AndroidWorkerClass(), true);
						
			outputChannel = androidWorker.createMessageChannel(Worker.current);
			outputChannel.addEventListener(Event.CHANNEL_MESSAGE, handleProgressMessage);
			androidWorker.setSharedProperty(WorkerStatus.OUTPUT_CHANNEL, outputChannel);
			
			androidWorker.addEventListener(Event.WORKER_STATE, handleBGWorkerStateChange);
			
			inputChannel = Worker.current.createMessageChannel(androidWorker);
			androidWorker.setSharedProperty(WorkerStatus.INPUT_CHANNEL, inputChannel);
			
			androidWorker.start();
		}
		
		private function handleBGWorkerStateChange(event:Event):void
		{
			if (androidWorker.state == WorkerState.RUNNING){
				androidWorker.removeEventListener(Event.WORKER_STATE, handleBGWorkerStateChange);
				inputChannel.send(startDriverArgs);
				inputChannel.close();
			}
		}
		
		private function handleProgressMessage(event:Event):void
		{
			var workerStatus:Array = outputChannel.receive() as Array;
			var messageType:String = workerStatus[1];
			
			if(workerStatus[0] == 1){ // it's an error

				terminate();
				
				if(messageType == WorkerStatus.LAN_ERROR){
					//TODO show specific error to user
				}else if(messageType == WorkerStatus.EXECUTE_ERROR){
					//TODO show specific error to user
				}
				
				status = FAIL
				connected = false;
				
				dispatchEvent(new Event("deviceStopped"));
				
			}else{
				if(messageType == WorkerStatus.IP_ADDRESS){
					ip = workerStatus[2];
				}else if(messageType ==WorkerStatus.STARTING){
					status = INSTALL;
				}else if(messageType ==WorkerStatus.DEVICE_INFO){
					manufacturer = workerStatus[2]
					modelId = workerStatus[3];
					modelName = workerStatus[4];
					androidVersion = workerStatus[5];
					androidSdk = workerStatus[6];
				}else if(messageType == WorkerStatus.RUNNING){
					status = READY
					tooltip = "Android " + androidVersion + ", API " + androidSdk + " [" + id + "]\nready and waiting testing actions"
				}else if(messageType == WorkerStatus.STOPPED){
					terminate();
					dispatchEvent(new Event("deviceStopped"));
				}
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