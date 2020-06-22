package com.ats.managers
{
import com.ats.device.simulator.genymotion.GenymotionInstance;
import com.ats.device.simulator.genymotion.GenymotionRecipe;
import com.ats.managers.gmsaas.GmsaasInstaller;
import com.ats.managers.gmsaas.GmsaasManager;

import mx.collections.ArrayCollection;
import mx.collections.Sort;

public class GenymotionManager {

	[Bindable]
	public var recipes:ArrayCollection
	private var existingInstances:ArrayCollection

	[Bindable]
	public var loading:Boolean = false;

	[Bindable]
	public var visible:Boolean = GmsaasInstaller.isInstalled()

	public function fetchContent():void {
		loading = true

		fetchRecipesList()
		fetchInstancesList()
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
		existingInstances = new ArrayCollection()
		fetchingInstances = true

		GmsaasManager.getInstance().fetchInstances(function (results:Array, error:String):void {
			fetchingInstances = false

			if (error) {
				trace(error)
				return
			}

			existingInstances = new ArrayCollection(results)

			if (!fetchingRecipes) {
				exec()
			}
		})
	}

	private function exec():void {
		var instance:GenymotionInstance;
		for each (instance in existingInstances) {
			attachInstance(instance)
		}

		loading = false
	}

	private function attachInstance(instance:GenymotionInstance):void {
		for each (var recipe:GenymotionRecipe in recipes) {
			if (recipe.uuid == instance.recipeUuid) {
				recipe.addInstance(instance)
				instance.adbConnect()
				break
			}
		}
	}

	public function terminate():void {
		for each (var recipe:GenymotionRecipe in recipes) {
			for each (var instance:GenymotionInstance in recipe.instances) {
				instance.adbDisconnect()
			}
		}
	}
}

}