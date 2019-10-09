package worker
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.net.registerClassAlias;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	
	public class AndroidWorker extends Sprite
	{
		private const androidDriverFullName:String = "com.ats.atsdroid";
		private const androidPropValueRegex:RegExp = /.*:.*\[(.*)\]/;
		
		private var outputChannel:MessageChannel;
		
		private var port:String;
		private var id:String;
		private var atsdroidFilePath;
		
		private var output:String = "";
		private var error:String;
		
		private var process:NativeProcess;
		private var procInfo:NativeProcessStartupInfo
		
		public function AndroidWorker()
		{
			registerClassAlias("worker.DeviceInfo", DeviceInfo);
			registerClassAlias("worker.DeviceIp", DeviceIp);
			registerClassAlias("worker.WorkerError", WorkerError);			
			
			const currentWorker:Worker = Worker.current;
			outputChannel = currentWorker.getSharedProperty(WorkerStatus.OUTPUT_CHANNEL) as MessageChannel;
			
			atsdroidFilePath = currentWorker.getSharedProperty("atsdroidFilePath") as String
			port = currentWorker.getSharedProperty("port") as String
			id = currentWorker.getSharedProperty("id") as String
			
			var adbFile:File = new File(currentWorker.getSharedProperty("adbFilePath"));
			
			process = new NativeProcess();
			procInfo = new NativeProcessStartupInfo()
						
			procInfo.executable = adbFile;
			procInfo.workingDirectory = adbFile.parent;
			
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onReadLanExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "ip", "route"];
			
			outputChannel.send(WorkerStatus.STARTING);
			
			process.start(procInfo);
		}
	
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			error = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
		}
		
		protected function onReadLanData(event:ProgressEvent):void{
			output += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
		}
		
		protected function onReadLanExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadLanExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData);
			
			if(error != null){
				outputChannel.send(new WorkerError(WorkerStatus.LAN_ERROR, error));
			}else{
				var ipRouteData:Array = output.split(/\s+/g);
				var idx:int = ipRouteData.indexOf("dev");
				if(idx > -1 && ipRouteData[idx+1] == "wlan0"){
					idx = ipRouteData.indexOf("src");
					if(idx > -1){

						outputChannel.send(new DeviceIp(ipRouteData[idx+1]));
					
						process.addEventListener(NativeProcessExitEvent.EXIT, onUninstallExit, false, 0, true);
						procInfo.arguments = new <String>["-s", id, "shell", "pm", "uninstall", androidDriverFullName];
						process.start(procInfo);

						return;
					}
				}
			}
		}
		
		protected function onUninstallExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onUninstallExit);
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onInstallExit, false, 0, true);
			procInfo.arguments = new <String>["-s", id, "install", "-r", atsdroidFilePath];
			
			outputChannel.send(WorkerStatus.INSTALL);
			process.start(procInfo);
		}
		
		protected function onInstallExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(NativeProcessExitEvent.EXIT, onInstallExit);
			
			output = "";
			process.addEventListener(NativeProcessExitEvent.EXIT, onGetPropExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadPropertyData, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "getprop"];
			process.start(procInfo);
		}
		
		protected function onReadPropertyData(event:ProgressEvent):void{
			output += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable).replace(/\r/g, "");
		}
		
		protected function onGetPropExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadPropertyData);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onGetPropExit);
			
			var deviceInfo:DeviceInfo = new DeviceInfo();
			
			var propArray:Array = output.split("\n");
			for each (var line:String in propArray){
				if(line.indexOf("[ro.product.brand]") == 0){
					deviceInfo.manufacturer = getPropValue(line)
				}else if(line.indexOf("[ro.product.model]") == 0){
					deviceInfo.modelId = getPropValue(line)
				}else if(line.indexOf("[ro.semc.product.name]") == 0){
					deviceInfo.modelName = getPropValue(line)
				}else if(line.indexOf("[def.tctfw.brandMode.name]") == 0){
					deviceInfo.modelName = getPropValue(line)
				}else if(line.indexOf("[ro.build.version.release]") == 0){
					deviceInfo.androidVersion = getPropValue(line)
				}else if(line.indexOf("[ro.build.version.sdk]") == 0){
					deviceInfo.androidSdk = getPropValue(line)
				}
			}
			
			deviceInfo.checkName();
			outputChannel.send(deviceInfo);
			
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onExecuteExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteData, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "am", "instrument", "-w", "-r", "-e", "atsPort", port, "-e", "debug", "false", "-e", "class", androidDriverFullName + ".AtsRunner", androidDriverFullName + "/android.support.test.runner.AndroidJUnitRunner"];
			process.start(procInfo);
		}
		
		private function getPropValue(value:String):String{
			return androidPropValueRegex.exec(value)[1];
		}
		
		protected function onExecuteError(event:ProgressEvent):void
		{
			error = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
		}
		
		protected function onExecuteData(event:ProgressEvent):void{
			//var data:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
			outputChannel.send(WorkerStatus.RUNNING);
		}
		
		protected function onExecuteExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onExecuteExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteData);
			
			if(error != null){
				outputChannel.send(new WorkerError(WorkerStatus.EXECUTE_ERROR, error));
			}else{
				outputChannel.send(WorkerStatus.STOPPED);
			}
		}
	}
}