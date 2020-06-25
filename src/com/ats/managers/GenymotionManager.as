package com.ats.managers
{
import com.ats.device.simulator.Simulator;
import com.ats.device.simulator.genymotion.GenymotionSaasSimulator;
import com.ats.device.simulator.genymotion.GenymotionRecipe;
import com.ats.managers.gmsaas.GmsaasInstaller;
import com.ats.managers.gmsaas.GmsaasManager;

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

		GmsaasManager.getInstance().fetchRecipes(function (results:Array, error:String):void {
			fetchingRecipes = false

			if (error) {
				trace(error);
				return
			}

			recipes = new ArrayCollection(results)

			var srt:Sort = new Sort();
			srt.compareFunction = function (a:GenymotionRecipe, b:GenymotionRecipe, array:Array = null):int {
				return b.version.compare(a.version)
			}
			recipes.sort = srt;
			recipes.refresh();

			if (!fetchingInstances) {
				exec()
			}
		})
	}

	private var fetchingInstances:Boolean = false
	private function fetchInstancesList():void {
		instances = new ArrayCollection()
		fetchingInstances = true

		GmsaasManager.getInstance().fetchInstances(function (results:Array, error:String):void {
			fetchingInstances = false

			if (error) {
				trace(error)
				return
			}

			instances = new ArrayCollection(results)

			if (!fetchingRecipes) {
				exec()
			}
		})
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