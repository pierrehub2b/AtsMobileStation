package com.ats.managers
{
	import com.ats.device.simulator.Simulator;
	import com.ats.device.simulator.genymotion.GenymotionRecipe;
	import com.ats.device.simulator.genymotion.GenymotionSaasSimulator;
	import com.ats.helpers.Settings;
	import com.ats.managers.gmsaas.GmsaasInstaller;
	import com.ats.managers.gmsaas.GmsaasManager;
	import com.ats.managers.gmsaas.GmsaasManagerEvent;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	import mx.collections.Sort;
	import mx.core.FlexGlobals;
	
	public class GenymotionManager extends EventDispatcher {
		
		[Bindable]
		public var recipes:ArrayCollection
		
		[Bindable]
		public var instances:ArrayCollection
		
		[Bindable]
		public var loading:Boolean = false;
		
		[Bindable]
		public var visible:Boolean = GmsaasInstaller.isInstalled()
		
		public function fetchContent():void {
			loading = true
			
			cleanGenymotionInstances()
			fetchRecipesList()
			fetchInstancesList()
		}
		
		private function cleanGenymotionInstances():void {
			var allSimulators:ArrayCollection = FlexGlobals.topLevelApplication.simulators.collection
			var genymotionInstances:ArrayCollection = new ArrayCollection(allSimulators.toArray())
			genymotionInstances.filterFunction = function(item:Object):Boolean { return item is GenymotionSaasSimulator }
			genymotionInstances.refresh()
			
			for each (var instance:Simulator in genymotionInstances) { allSimulators.removeItem(instance) }
		}
		
		private var fetchingRecipes:Boolean = false
		public function fetchRecipesList():void {
			recipes = new ArrayCollection()
			fetchingRecipes = true
			
			var manager:GmsaasManager = new GmsaasManager()
			manager.addEventListener(GmsaasManagerEvent.COMPLETED, fetchRecipesListCompletedHandler, false, 0, true)
			manager.addEventListener(GmsaasManagerEvent.ERROR, fetchRecipesListErrorHandler, false, 0, true)
			manager.fetchRecipes()
		}
		
		private function fetchRecipesListCompletedHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, fetchRecipesListCompletedHandler)
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, fetchRecipesListErrorHandler)
			fetchingRecipes = false
			
			recipes = new ArrayCollection(event.data)
			
			var srt:Sort = new Sort();
			srt.compareFunction = function (a:GenymotionRecipe, b:GenymotionRecipe, array:Array = null):int {
				return b.version.compare(a.version)
			}
				
			recipes.sort = srt;
			recipes.refresh();
			
			if (!fetchingInstances) {
				exec()
			}
		}
		
		private function fetchRecipesListErrorHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, fetchRecipesListCompletedHandler)
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, fetchRecipesListErrorHandler)
			fetchingRecipes = false
		}
		
		private var fetchingInstances:Boolean = false
		private function fetchInstancesList():void {
			instances = new ArrayCollection()
			fetchingInstances = true
			
			var manager:GmsaasManager = new GmsaasManager()
			manager.addEventListener(GmsaasManagerEvent.COMPLETED, fetchInstancesListCompletedHandler, false, 0, true)
			manager.addEventListener(GmsaasManagerEvent.ERROR, fetchInstancesListErrorHandler, false, 0, true)
			manager.fetchInstances()
		}
		
		private function fetchInstancesListCompletedHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, fetchInstancesListCompletedHandler)
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, fetchInstancesListErrorHandler)
			fetchingInstances = false
			
			instances = new ArrayCollection(event.data)
			GenymotionSaasSimulator.count = instances.length;
			
			if (!fetchingRecipes) {
				exec()
			}
		}
		
		private function fetchInstancesListErrorHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, fetchInstancesListCompletedHandler)
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, fetchInstancesListErrorHandler)
			fetchingInstances = false
		}
		
		private function exec():void {
			var instance:GenymotionSaasSimulator;
			for each (instance in instances) {
				attachInstance(instance)
			}
			loading = false
		}
		
		private function attachInstance(instance:GenymotionSaasSimulator):void {
			for each (var recipe:GenymotionRecipe in recipes) {
				if (recipe.uuid == instance.recipeUuid) {
					instance.statusOn()
					recipe.addInstance(instance)
					
					if (instance.owned) {
						instance.adbConnect()
					}
					
					break
				}
			}
		}

		private var ownedInstances:Vector.<GenymotionSaasSimulator>
		private function stopAllInstances():void {
			if (!ownedInstances) {
				ownedInstances = new Vector.<GenymotionSaasSimulator>()
				for each (var recipe:GenymotionRecipe in recipes) {
					for each (var instance:GenymotionSaasSimulator in recipe.instances) {
						if (instance.owned) {
							ownedInstances.push(instance)
						}
					}
				}
			}

			var instance:GenymotionSaasSimulator = ownedInstances.pop()
			instance.addEventListener(Event.CLOSE, instanceStoppedHandler)
			instance.stopSim()
		}

		private function instanceStoppedHandler(event:Event):void {
			var instance:GenymotionSaasSimulator = event.currentTarget as GenymotionSaasSimulator
			instance.removeEventListener(Event.CLOSE, instanceStoppedHandler)

			if (ownedInstances.length > 0) {
				stopAllInstances()
			} else {
				stopAdbTunnel()
			}
		}

		private function stopAdbTunnel():void {
			const pythonFolder:File = Settings.getInstance().pythonFolder;
			if(pythonFolder != null && pythonFolder.exists){
				const gmTunnelDaemon:File = pythonFolder.resolvePath("Lib/site-packages/gmsaas/adbtunnel/gmadbtunneld/gmadbtunneld.exe");
				if(gmTunnelDaemon.exists){
					var proc:NativeProcess = new NativeProcess();
					var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
					procInfo.executable = gmTunnelDaemon;
					procInfo.arguments = new <String>["stop"];

					proc.addEventListener (NativeProcessExitEvent.EXIT, stopAdbTunnelExit);
					proc.start(procInfo);
				}else{
					dispatchEvent(new Event(Event.COMPLETE))
				}
			}else{
				dispatchEvent(new Event(Event.COMPLETE))
			}
		}
		
		public function terminate():void {
			stopAllInstances()
		}
		
		private function stopAdbTunnelExit(ev:NativeProcessExitEvent):void{
			ev.currentTarget.removeEventListener(NativeProcessExitEvent.EXIT, stopAdbTunnelExit);
			dispatchEvent(new Event(Event.COMPLETE))
		}
	}
}