package
{
import com.ats.device.simulator.GenymotionSimulator;
import com.ats.device.simulator.GenymotionDeviceTemplate;
import com.ats.helpers.Settings;
import com.ats.helpers.Version;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

import mx.collections.ArrayCollection;
import mx.core.FlexGlobals;
import mx.utils.StringUtil;

public class GenymotionManager
	{
		private var pipFile:File;
		private var gmsaasFile:File;
		
		[Bindable]
		public var recipes:ArrayCollection;

		private var errorData:String
		private var outputData:String

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
			if (!gmsaasFile.exists) {
				trace('WARNING : gmsaas file not found')
				return
			}

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
		
		private function gmInstallExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmInstallExit);
			
			defineAndroidSdk();
			defineJSONOutputFormat()

			loadRecipesList();
		}
		
		public function defineAndroidSdk():void{
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = new <String>["config", "set", "android-sdk-path", Settings.getInstance().androidSdkPath];
			
			var proc:NativeProcess = new NativeProcess();
			proc.start(procInfo);
		}

		public function defineJSONOutputFormat():void{
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = new <String>["config", "set", "output-format", "compactjson"];

			var proc:NativeProcess = new NativeProcess();
			proc.start(procInfo);
		}
		
		public function loadRecipesList():void{
			recipes = new ArrayCollection();
			outputData = "";

			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = new <String>["recipes", "list"];
					
			var proc:NativeProcess = new NativeProcess();
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputHandler);
			proc.addEventListener(NativeProcessExitEvent.EXIT, gmsaasRecipesListExit);
			proc.start(procInfo);
		}

		private function gmsaasRecipesListExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputHandler);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmsaasRecipesListExit);

			var json:Object = JSON.parse(outputData)
			for each (var info:Object in json.recipes) {
				var recipe:GenymotionDeviceTemplate = new GenymotionDeviceTemplate(info, gmsaasFile)
				if (recipe.version.compare(new Version("5.1")) != com.ats.helpers.Version.INFERIOR) {
					recipes.addItemAt(recipe, 0)
				}
			}

			loadInstancesList();
		}

		public function loadInstancesList():void {
			outputData = ""

			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = new <String>["instances", "list"];
				
			var proc:NativeProcess = new NativeProcess();
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputHandler);
			proc.addEventListener(NativeProcessExitEvent.EXIT, gmsaasInstancesListExit);
			proc.start(procInfo);
		}

		private function processOutputHandler(event:ProgressEvent):void {
			var proc:NativeProcess = event.currentTarget as NativeProcess
			outputData += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}

		private function gmsaasInstancesListExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputHandler);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmsaasInstancesListExit);

			var json:Object = JSON.parse(outputData)
			for each (var info:Object in json.instances) {
				var instance:GenymotionSimulator = new GenymotionSimulator(info)
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
			var searchName:String = instance.templateName.split("_")[0]

			for each (var recipe:GenymotionDeviceTemplate in recipes) {
				if (recipe.name == searchName) {
					recipe.addInstance(instance)
					break
				}
			}
		}
	}
}