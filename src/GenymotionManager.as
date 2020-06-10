package
{
import com.ats.device.GenymotionSimulator;
import com.ats.device.simulator.GenymotionDeviceTemplate;
import com.ats.helpers.Settings;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

import mx.collections.ArrayCollection;
import mx.utils.StringUtil;

public class GenymotionManager
	{
		private static const recipeDataRegexp:RegExp = /(^.{36})\s*(.{29})\s*((\.?\d+)+)\s*(\d+) x (\d+)\s*dpi (\d+).*/
		// private static const instanceDataRegexp:RegExp = /(^.{36})\s*(.{29})\s*((\.?\d+)+)\s*(\d+) x (\d+)\s*dpi (\d+).*/

		private var pipFile:File;
		private var gmsaasFile:File;
		
		[Bindable]
		public var recipes:ArrayCollection;
		
		public function GenymotionManager()
		{
			//TODO check Genymotion account defined
			
			if (!Settings.getInstance().androidSdkPath) {
				trace('WARNING : Android SDK path not set')
				return
			}
				
			var pythonFileName:String = "python";
			var pipFileName:String = "pip3";
			var gmsaasFileName:String = "gmsaas";
			if (!Settings.isMacOs) {
				pythonFileName += ".exe";
				pipFileName += ".exe";
				gmsaasFileName += ".exe"
			}

			const pythonFolder:File = Settings.getInstance().pythonFolder;
			if (!pythonFolder) {
				trace('WARNING : Python folder path not set')
				return
			}

			var pythonFile:File = pythonFolder.resolvePath(pythonFileName);
			if (!pythonFile.exists) {
				trace('WARNING : Python file not found')
				return
			}

			pipFile = pythonFolder.resolvePath("Scripts").resolvePath(pipFileName);
			if (!pipFile.exists) {
				trace('WARNING : PIP file not found')
				return
			}

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
					
					recipes = new ArrayCollection();
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
				addRecipe(recipes, data[i]);
			}
			
			loadInstancesList();
		}

		private function addRecipe(list:ArrayCollection, data:String):void{
			if(data.length > 0){
				const dataArray:Array = data.split(recipeDataRegexp);
				if(dataArray.length > 6){
					list.addItemAt(new GenymotionDeviceTemplate(dataArray, gmsaasFile), 0);
				}
			}
		}
		
		public function loadInstancesList():void{
			if(gmsaasFile != null && gmsaasFile.exists){
				loadData = "";

				var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				procInfo.executable = gmsaasFile;
				procInfo.arguments = new <String>["instances", "list"];
				
				var proc:NativeProcess = new NativeProcess();
				proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstancesListOutput);
				proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, gmsaasInstancesListError);
				proc.addEventListener(NativeProcessExitEvent.EXIT, gmsaasInstancesListExit);
				
				proc.start(procInfo);
			}
		}
		
		private function gmsaasInstancesListOutput(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess
			loadData += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}

		private var errorData:String
		private function gmsaasInstancesListError(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess
			errorData += proc.standardError.readUTFBytes(proc.standardError.bytesAvailable);
		}
		
		private function gmsaasInstancesListExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstancesListOutput);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmsaasInstancesListExit);

			if (errorData) {
				trace(errorData)
				return
			}

			var data:Array = loadData.split(File.lineEnding);
			var delimiters:Array = data[1].split("  ")

			for(var i:int=2; i<data.length; i++) {
				var info:String = data[i]
				if (!info) return

				var uuid:String = info.substr(0, (delimiters[0] as String).length)
				var name:String = StringUtil.trim(info.substr((delimiters[0] as String).length + 2, (delimiters[1] as String).length))
				var adbSerial:String = StringUtil.trim(info.substr((delimiters[0] as String).length + 2 + (delimiters[1] as String).length + 2, (delimiters[2] as String).length))
				var state:String =  StringUtil.trim(info.substr((delimiters[0] as String).length + 2 + (delimiters[1] as String).length + 2 + (delimiters[2] as String).length + 2, (delimiters[3] as String).length))

				var instance:GenymotionSimulator = new GenymotionSimulator(uuid, name, adbSerial, state)
				fetchInstanceTemplateName(instance)
			}
		}

		private function fetchInstanceTemplateName(instance:GenymotionSimulator):void {
			instance.addEventListener(GenymotionSimulator.EVENT_TEMPLATE_NAME_FOUND, fetchInstanceTemplateNameHandler)
			instance.gmsaasFile = gmsaasFile
			instance.adbConnect()
		}

		private function fetchInstanceTemplateNameHandler(event:Event):void {
			var instance:GenymotionSimulator = event.currentTarget as GenymotionSimulator
			attachInstance(instance)
		}

		private function attachInstance(instance:GenymotionSimulator):void {
			for each (var recipe:GenymotionDeviceTemplate in recipes) {
				if (recipe.name == instance.templateName) {
					recipe.addInstance(instance)
					break
				}
			}
		}
	}
}