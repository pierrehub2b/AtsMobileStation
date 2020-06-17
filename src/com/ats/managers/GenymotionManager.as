package com.ats.managers
{
import com.ats.device.simulator.GenymotionRecipe;
import com.ats.device.simulator.GenymotionSimulator;
import com.ats.helpers.Settings;
import com.ats.managers.gmsaas.GmsaasManager;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.NativeProcessExitEvent;
import flash.filesystem.File;

import mx.collections.ArrayCollection;
import mx.collections.Sort;
import mx.collections.SortField;

public class GenymotionManager
	{
		private var pipFile:File;
		public var gmsaasFile:File;
		
		[Bindable]
		public var recipes:ArrayCollection
		private var existingInstances:ArrayCollection
		
		[Bindable]
		public var loading:Boolean

		public var enabled:Boolean = false
		
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

			enabled = true

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
			
			// defineJSONOutputFormat()
			defineAndroidSdk();
			
			fetchContent()
		}
		
		public function fetchContent():void {
			loading = true
			
			fetchRecipesList()
			fetchInstancesList()
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
		
		private var fetchingRecipes:Boolean = false
		public function fetchRecipesList():void {
			fetchingRecipes = true
			GmsaasManager.getInstance().fetchRecipes(function(results:Array, error:String):void {
				fetchingRecipes = false

				if (error) {
					trace(error);
					return
				}

				recipes = new ArrayCollection(results)
				var srt:Sort = new Sort();
				srt.compareFunction = function(a:GenymotionRecipe, b:GenymotionRecipe, array:Array = null):int {
					return b.version.compare(a.version)
				}
				recipes.sort = srt;
				recipes.refresh();

				if (existingInstances && !fetchingInstances) {
					exec()
				}
			})
		}
		
		private var fetchingInstances:Boolean = false
		private function fetchInstancesList():void {
			fetchingInstances = true
			GmsaasManager.getInstance().fetchInstances(function(results:Array, error:String):void {
				fetchingInstances = false

				if (error) {
					trace(error)
					return
				}

				existingInstances = new ArrayCollection(results)

				if (recipes && !fetchingRecipes) {
					exec()
				}
			})
		}

		private function exec():void {
			var instance:GenymotionSimulator; 
			for each (instance in existingInstances) {
				attachInstance(instance)
			}
			
			for each (instance in existingInstances) {
				if (!instance.template) fetchInstanceTemplateName(instance)
			}
			
			loading = false
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
			// to refactor
			var searchName:String
			if (instance.templateName) searchName = instance.templateName.split("_")[0]
			if (instance.name) searchName = instance.name.split("_")[0]
			
			for each (var recipe:GenymotionRecipe in recipes) {
				if (recipe.name == searchName) {
					recipe.addInstance(instance)
					instance.adbConnect()
					// existingInstances.removeItem(instance)
					break
				}
			}
		}
		
		public function numberOfInstances():int {
			var count:int = 0
			for each (var recipe:GenymotionRecipe in recipes) {
				count += recipe.instances.length
			}
			
			return count
		}
	}
}