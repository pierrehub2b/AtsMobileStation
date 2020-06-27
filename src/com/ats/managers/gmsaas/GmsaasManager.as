package com.ats.managers.gmsaas {
	
	import com.ats.device.simulator.genymotion.GenymotionRecipe;
	import com.ats.device.simulator.genymotion.GenymotionSaasSimulator;
	import com.ats.helpers.Settings;
	import com.ats.helpers.Version;
	
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	
	public class GmsaasManager extends EventDispatcher {

		public function fetchRecipes():void {
			GmsaasProcess.startProcess(["recipes", "list"], fetchRecipesExitHandler);
		}
		
		private function fetchRecipesExitHandler(json:Object):void {
			
			if(handleData(json)){
				if(json.hasOwnProperty("recipes")){
					
					var recipesInfo:Array = json["recipes"]
					var recipes:Array = []
						
					for each (var info:Object in recipesInfo) {
						var recipe:GenymotionRecipe = new GenymotionRecipe(info)
						if (recipe.version.compare(new Version("5.1")) != Version.INFERIOR) {
							recipes.push(recipe)
						}
					}
					
					dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, recipes, null))
				}else{
					dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, "No recipes array data found"))
				}
			}
		}
		
		public function fetchInstances():void {
			GmsaasProcess.startProcess(["instances", "list"], fetchInstancesExitHandler);
		}
		
		private function fetchInstancesExitHandler(json:Object):void {
			
			if(handleData(json)){
				if(json.hasOwnProperty("instances")){
					
					var instancesInfo:Array = json["instances"]
					var instances:Array = []

					for each (var info:Object in instancesInfo) {
						try {
							instances.push(new GenymotionSaasSimulator(info))
						} catch (error:Error) { trace(error.message) }
					}
					dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, instances, null))
				}else{
					dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, "No instances array data found"))
				}
			}
		}
		
		public function startInstance(recipeUuid:String, instanceName:String):void {
			GmsaasProcess.startProcess(["instances", "start", recipeUuid, instanceName], adbConnectionExitHandler);
		}
		
		public function stopInstance(instanceUuid:String):void {
			GmsaasProcess.startProcess(["instances", "stop", instanceUuid], adbConnectionExitHandler);
		}
		
		public function adbConnect(instanceUuid:String):void {
			GmsaasProcess.startProcess(["instances", "adbconnect", instanceUuid], adbConnectionExitHandler);
		}
		
		public function adbDisconnect(instanceUuid:String):void {
			if(instanceUuid != null){
				GmsaasProcess.startProcess(["instances", "adbdisconnect", instanceUuid], adbConnectionExitHandler);
			}else{
				dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, "Instance uuid is null !"))
			}
		}
		
		private function adbConnectionExitHandler(json:Object):void {
			if(handleData(json)){
				if(json.hasOwnProperty("instance")){
					dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, [new GenymotionSaasSimulator(json["instance"])], null))
				}else{
					dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, "No instance data found"))
				}
			}
		}
		
		/* public function whoami(callback:Function):void {
		var process:GmsaasProcess = new GmsaasProcess(callback)
		var parameters:Vector.<String> = new <String>["auth", "whoami"]
		
		executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
		// removeProcess(event)
		
		var json:Object = handleOutput(process.data)
		if (!json) return;
		
		process.callback(json.auth.email, null)
		})
		} */
		
		public function login(email:String, password:String):void {
			GmsaasProcess.startProcess(["auth", "login", email, password], loginExitHandler);
		}
		
		private function loginExitHandler(json:Object):void {
			if (handleData(json)){
				dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, null, null))
			}
		}
		
		/* public function logout(callback:Function):void {
		var process:GmsaasProcess = new GmsaasProcess(callback)
		var parameters:Vector.<String> = new <String>["auth", "logout"]
		
		executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
		// removeProcess(event)
		
		var json:Object = handleOutput(process.data)
		if (!json) return;
		process.callback(json.auth, null)
		})
		} */
		
		// // // //
		// COMMON
		// // // //
		
		//private function executeProcess(parameters:Vector.<String>, exitFunction:Function):void {
		//	new GmsaasProcess(gmsaasFile, parameters, exitFunction).start();
		//}
		
		/*private function processOutputDataHandler(event:ProgressEvent):void {
		var process:DataProcess = event.currentTarget as DataProcess
		var input:IDataInput
		
		switch (event.type) {
		case ProgressEvent.STANDARD_OUTPUT_DATA:
		input = process.standardOutput
		break
		case ProgressEvent.STANDARD_ERROR_DATA:
		input = process.standardError
		break
		}
		
		process.data += input.readUTFBytes(input.bytesAvailable)
		}*/
		
		private function handleData(json:Object):Boolean {
			if ('error' in json) {
				dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, json.error.message))
				return false
			}
			return true
		}
		
		/* public function stopAllProcesses():void {
		processes.forEach(function(process:DataProcess, index:int, vector:Vector.<DataProcess>):void {
		process.exit(true)
		})
		} */
	}
}
