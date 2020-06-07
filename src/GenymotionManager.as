package
{
	import com.ats.device.simulator.GenymotionDevice;
	import com.ats.helpers.Settings;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	public class GenymotionManager
	{
		private static const dataRegexp:RegExp = /(^.{36})\s*(.{29})\s*((\.?\d+)+)\s*(\d+) x (\d+)\s*dpi (\d+).*/
		
		private var genyMotionLogin:String = "dev@agilitest.com"
		
		private var pipFile:File;
		private var gmsaasFile:File;
		
		[Bindable]
		public var devices:ArrayCollection;
		
		[Bindable]
		public var runningDevices:ArrayCollection;
		
		public function GenymotionManager()
		{
			//TODO check Genymotion account defined
			
			if(Settings.getInstance().androidSdkPath != null){
				
				var pythonFileName:String = "python";
				var pipFileName:String = "pip3";
				var gmsaasFileName:String = "gmsaas";
				if(!Settings.isMacOs){
					pythonFileName += ".exe";
					pipFileName += ".exe";
					gmsaasFileName += ".exe"
				}
				
				const pythonFolder:File = Settings.getInstance().pythonFolder;
				var pythonFile:File = pythonFolder.resolvePath(pythonFileName);
				if(pythonFile.exists){
					pipFile = pythonFolder.resolvePath("Scripts").resolvePath(pipFileName);
					if(pipFile.exists){
						
						gmsaasFile = pythonFolder.resolvePath("Scripts").resolvePath(gmsaasFileName);
						
						var args:Vector.<String> = new Vector.<String>();
						args.push("-m");
						args.push("pip");
						args.push("install");
						args.push("--upgrade");
						args.push("pip");
						
						var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
						procInfo.executable = pythonFile;
						procInfo.arguments = args;
						
						var proc:NativeProcess = new NativeProcess();
						proc.addEventListener(NativeProcessExitEvent.EXIT, upgradePipExit);
						
						proc.start(procInfo);
					}
				}
			}
		}
		
		private function upgradePipExit(event:NativeProcessExitEvent):void{
			
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(NativeProcessExitEvent.EXIT, upgradePipExit);
			
			var args:Vector.<String> = new Vector.<String>();
			args.push("install");
			args.push("--upgrade");
			args.push("gmsaas");
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = pipFile;
			procInfo.arguments = args;
			
			var newProc:NativeProcess = new NativeProcess();
			newProc.addEventListener(NativeProcessExitEvent.EXIT, gmInstallExit);
			newProc.start(procInfo);
		}
		
		private var loadData:String
		private function gmInstallExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmInstallExit);
			
			defineAndroidSdk();
			loadRecipesList();
		}
		
		public function defineAndroidSdk():void{
			
			var args:Vector.<String> = new Vector.<String>();
			args.push("config");
			args.push("set");
			args.push("android-sdk-path");
			args.push(Settings.getInstance().androidSdkPath);
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = args;
			
			var proc:NativeProcess = new NativeProcess();
			proc.start(procInfo);
		}
		
		public function loadRecipesList():void{
			if(gmsaasFile != null && gmsaasFile.exists){
				if(Settings.getInstance().androidSdkPath != null){
					
					devices = new ArrayCollection();
					loadData = "";
					
					var args:Vector.<String> = new Vector.<String>();
					args.push("recipes");
					args.push("list");
					
					var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
					procInfo.executable = gmsaasFile;
					procInfo.arguments = args;
					
					var proc:NativeProcess = new NativeProcess();
					proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasRecipesList);
					proc.addEventListener(NativeProcessExitEvent.EXIT, gmsaasRecipesListExit);
					
					proc.start(procInfo);
				}
			}
		}
		
		private function gmsaasRecipesList(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess
			loadData += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}
		
		private function gmsaasRecipesListExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasRecipesList);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmsaasRecipesListExit);
			
			var data:Array = loadData.split(File.lineEnding);
			
			for(var i:int=2; i<data.length; i++){
				addDevice(devices, data[i]);
			}
			
			loadInstancesList();
		}
		
		public function loadInstancesList():void{
			if(gmsaasFile != null && gmsaasFile.exists){
				
				runningDevices = new ArrayCollection();
				loadData = "";
				
				var args:Vector.<String> = new Vector.<String>();
				args.push("instances");
				args.push("list");
				
				var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				procInfo.executable = gmsaasFile;
				procInfo.arguments = args;
				
				var proc:NativeProcess = new NativeProcess();
				proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstancesList);
				proc.addEventListener(NativeProcessExitEvent.EXIT, gmsaasInstancesListExit);
				
				proc.start(procInfo);
			}
		}
		
		private function gmsaasInstancesList(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess
			loadData += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}
		
		private function gmsaasInstancesListExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstancesList);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmsaasInstancesListExit);
			
			var data:Array = loadData.split(File.lineEnding);
			
			for(var i:int=2; i<data.length; i++){
				addDevice(runningDevices, data[i]);
			}
		}
		
		private function addDevice(list:ArrayCollection, data:String):void{
			if(data.length > 0){
				const dataArray:Array = data.split(dataRegexp);
				if(dataArray.length > 6){
					list.addItemAt(new GenymotionDevice(dataArray, gmsaasFile), 0);
				}
			}
		}
	}
}