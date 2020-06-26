package com.ats.managers
{
import com.ats.device.simulator.Simulator;
import com.ats.device.simulator.genymotion.GenymotionRecipe;
import com.ats.device.simulator.genymotion.GenymotionSaasSimulator;
import com.ats.managers.gmsaas.GmsaasInstaller;
import com.ats.managers.gmsaas.GmsaasManager;
import com.ats.managers.gmsaas.GmsaasManagerEvent;

import mx.collections.ArrayCollection;
import mx.collections.Sort;
import mx.core.FlexGlobals;

public class GenymotionManager {

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
		var manager:GmsaasManager = event.currentTarget as GmsaasManager
		manager.removeEventListener(GmsaasManagerEvent.COMPLETED, fetchRecipesListCompletedHandler)
		manager.removeEventListener(GmsaasManagerEvent.ERROR, fetchRecipesListErrorHandler)

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
		var manager:GmsaasManager = event.currentTarget as GmsaasManager
		manager.removeEventListener(GmsaasManagerEvent.COMPLETED, fetchRecipesListCompletedHandler)
		manager.removeEventListener(GmsaasManagerEvent.ERROR, fetchRecipesListErrorHandler)

		fetchingRecipes = false
		trace(event.error)
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
		var manager:GmsaasManager = event.currentTarget as GmsaasManager
		manager.removeEventListener(GmsaasManagerEvent.COMPLETED, fetchInstancesListCompletedHandler)
		manager.removeEventListener(GmsaasManagerEvent.ERROR, fetchInstancesListErrorHandler)

		fetchingInstances = false

		instances = new ArrayCollection(event.data)

		if (!fetchingRecipes) {
			exec()
		}
	}

	private function fetchInstancesListErrorHandler(event:GmsaasManagerEvent):void {
		var manager:GmsaasManager = event.currentTarget as GmsaasManager
		manager.removeEventListener(GmsaasManagerEvent.COMPLETED, fetchInstancesListCompletedHandler)
		manager.removeEventListener(GmsaasManagerEvent.ERROR, fetchInstancesListErrorHandler)

		fetchingInstances = false
		trace(event.error)
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

				if (instance.isMS) {
					instance.adbConnect()
				}

				break
			}
		}
	}

	public function terminate():void {
		for each (var recipe:GenymotionRecipe in recipes) {
			for each (var instance:GenymotionSaasSimulator in recipe.instances) {
				instance.adbDisconnect()
			}
		}
	}

	public function stopAllInstances():void {
		for each (var recipe:GenymotionRecipe in recipes) {
			recipe.stopAllInstances()
		}
	}
}

}