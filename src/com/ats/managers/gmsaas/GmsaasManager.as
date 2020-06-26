package com.ats.managers.gmsaas {

import com.ats.device.simulator.genymotion.GenymotionRecipe;
import com.ats.device.simulator.genymotion.GenymotionSaasSimulator;
import com.ats.helpers.Settings;
import com.ats.helpers.Version;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.EventDispatcher;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;
import flash.utils.IDataInput;

public class GmsaasManager extends EventDispatcher {

	private static const gmsaasFile:File = Settings.getInstance().pythonFolder.resolvePath("Scripts").resolvePath("gmsaas.exe")

	// private var processes:Vector.<DataProcess> = new Vector.<DataProcess>()

	public function fetchRecipes():void {
		var parameters:Vector.<String> = new <String>["recipes", "list"]
		executeProcess(parameters, fetchRecipesExitHandler)
	}

	private function fetchRecipesExitHandler(event:NativeProcessExitEvent):void {
		var process: DataProcess = event.currentTarget as DataProcess
		process.removeEventListener(NativeProcessExitEvent.EXIT, fetchRecipesExitHandler)
		process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputDataHandler)
		process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, processOutputDataHandler)

		var json:Object = handleOutput(process.data)
		if (!json) return;

		try {
			var recipes:Array = []
			var recipesInfo:Array = json['recipes']
			for each (var info:Object in recipesInfo) {
				var recipe:GenymotionRecipe = new GenymotionRecipe(info)
				if (recipe.version.compare(new Version("5.1")) != Version.INFERIOR) {
					recipes.push(recipe)
				}
			}

			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, recipes, null))
		} catch (error:Error) {
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, error.message))
		}
	}

	public function fetchInstances():void {
		var parameters:Vector.<String> = new <String>["instances", "list"]
		executeProcess(parameters, fetchInstancesExitHandler)
	}

	private function fetchInstancesExitHandler(event:NativeProcessExitEvent):void {
		var process: DataProcess = event.currentTarget as DataProcess
		process.removeEventListener(NativeProcessExitEvent.EXIT, fetchInstancesExitHandler)
		process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputDataHandler)
		process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, processOutputDataHandler)

		var json:Object = handleOutput(process.data)
		if (!json) return;

		try {
			var instances:Array = []
			var instancesInfo:Array = json['instances']
			for each (var info:Object in instancesInfo) {
				try {
					var instance:GenymotionSaasSimulator = new GenymotionSaasSimulator(info)
					instances.push(instance)
				} catch (error:Error) { trace(error.message) }
			}
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, instances, null))
		} catch (error:Error) {
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, error.message))
		}
	}

	public function startInstance(recipeUuid:String, instanceName:String):void {
		var parameters:Vector.<String> = new <String>["instances", "start", recipeUuid, instanceName]
		executeProcess(parameters, startInstanceExitHandler)
	}

	private function startInstanceExitHandler(event:NativeProcessExitEvent):void {
		var process: DataProcess = event.currentTarget as DataProcess
		process.removeEventListener(NativeProcessExitEvent.EXIT, loginExitHandler)
		process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputDataHandler)
		process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, processOutputDataHandler)

		var json:Object = handleOutput(process.data)
		if (!json) return;

		try {
			var info:Object = json['instance']
			var instance:GenymotionSaasSimulator = new GenymotionSaasSimulator(info)
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, [instance], null))
		} catch (error:Error) {
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, error.message))
		}
	}

	public function stopInstance(instanceUuid:String):void {
		var parameters:Vector.<String> = new <String>["instances", "stop", instanceUuid]
		executeProcess(parameters, stopInstanceExitHandler)
	}

	private function stopInstanceExitHandler(event:NativeProcessExitEvent):void {
		var process: DataProcess = event.currentTarget as DataProcess
		process.removeEventListener(NativeProcessExitEvent.EXIT, loginExitHandler)
		process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputDataHandler)
		process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, processOutputDataHandler)

		var json:Object = handleOutput(process.data)
		if (!json) return;

		try {
			var info:Object = json['instance']
			var instance:GenymotionSaasSimulator = new GenymotionSaasSimulator(info)
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, [instance], null))
		} catch (error:Error) {
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, error.message))
		}
	}

	public function adbConnect(instanceUuid:String):void {
		var parameters:Vector.<String> = new <String>["instances", "adbconnect", instanceUuid]
		executeProcess(parameters, adbConnectExitHandler)
	}

	private function adbConnectExitHandler(event:NativeProcessExitEvent):void {
		var process: DataProcess = event.currentTarget as DataProcess
		process.removeEventListener(NativeProcessExitEvent.EXIT, loginExitHandler)
		process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputDataHandler)
		process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, processOutputDataHandler)

		var json:Object = handleOutput(process.data)
		if (!json) return;

		try {
			var info:Object = json['instance']
			var instance:GenymotionSaasSimulator = new GenymotionSaasSimulator(info)
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, [instance], null))
		} catch (error:Error) {
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, error.message))
		}
	}

	public function adbDisconnect(instanceUuid:String):void {
		var parameters:Vector.<String> = new <String>["instances", "adbdisconnect", instanceUuid]
		executeProcess(parameters, adbDisconnectExitHandler)
	}

	private function adbDisconnectExitHandler(event:NativeProcessExitEvent):void {
		var process: DataProcess = event.currentTarget as DataProcess
		process.removeEventListener(NativeProcessExitEvent.EXIT, loginExitHandler)
		process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputDataHandler)
		process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, processOutputDataHandler)

		var json:Object = handleOutput(process.data)
		if (!json) return;

		try {
			var info:Object = json['instance']
			var instance:GenymotionSaasSimulator = new GenymotionSaasSimulator(info)
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, [instance], null))
		} catch (error:Error) {
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, error.message))
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
		var parameters:Vector.<String> = new <String>["auth", "login", email, password]
		executeProcess(parameters,loginExitHandler)
	}

	private function loginExitHandler(event:NativeProcessExitEvent):void {
		var process: DataProcess = event.currentTarget as DataProcess
		process.removeEventListener(NativeProcessExitEvent.EXIT, loginExitHandler)
		process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputDataHandler)
		process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, processOutputDataHandler)

		var json:Object = handleOutput(process.data)
		if (!json) return;

		dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.COMPLETED, null, null))
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

	private function executeProcess(parameters:Vector.<String>, exitFunction:Function):void {
		var arguments: Vector.<String> = new <String>["--format", "compactjson"]
		arguments = arguments.concat(parameters)

		var processInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
		processInfo.executable = gmsaasFile
		processInfo.arguments = arguments

		var process:DataProcess = new DataProcess()
		process.addEventListener(NativeProcessExitEvent.EXIT, exitFunction, false, 0, true)
		process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, processOutputDataHandler)
		process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, processOutputDataHandler)
		process.start(processInfo)
	}

	private function processOutputDataHandler(event:ProgressEvent):void {
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
	}

	private function handleOutput(outputData:String):Object {
		try {
			var json:Object = JSON.parse(outputData)

			if ('error' in json) {
				dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, json.error.message))
				return null
			}

			return json
		} catch (error:Error) {
			dispatchEvent(new GmsaasManagerEvent(GmsaasManagerEvent.ERROR, null, error.message))
		}

		return null
	}

	/* public function stopAllProcesses():void {
		processes.forEach(function(process:DataProcess, index:int, vector:Vector.<DataProcess>):void {
			process.exit(true)
		})
	} */
}
}
