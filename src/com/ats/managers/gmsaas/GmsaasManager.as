package com.ats.managers.gmsaas {

import com.ats.device.simulator.GenymotionRecipe;
import com.ats.device.simulator.GenymotionSimulator;
import com.ats.helpers.Settings;
import com.ats.helpers.Version;

import flash.desktop.NativeProcessStartupInfo;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

public class GmsaasManager {

    private static const gmsaasFile:File = Settings.getInstance().pythonFolder.resolvePath("Scripts").resolvePath("gmsaas.exe")
    private static var _instance:GmsaasManager;

    public function GmsaasManager(){
        if (_instance) {
            throw new Error("Singleton... use getInstance()");
        }
        _instance = this;
    }

    public static function getInstance():GmsaasManager{
        if (!_instance) {
            new GmsaasManager();
        }
        return _instance;
    }

    // Commands

    private var processes:Vector.<GmsaasProcess> = new Vector.<GmsaasProcess>()

    public function fetchRecipes(callback: Function):void {
        var process:GmsaasProcess = new GmsaasProcess(callback)
        var parameters:Vector.<String> = new <String>["recipes", "list"]

        executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
            // removeProcess(event)

            var json:Object = handleOutput(process.data, process.callback)
            if (!json) return;

            try {
                var recipes:Array = new Array()
                var recipesInfo:Array = json['recipes']
                for each (var info:Object in recipesInfo) {
                    var recipe:GenymotionRecipe = new GenymotionRecipe(info)
                    if (recipe.version.compare(new Version("5.1")) != Version.INFERIOR) {
                        recipes.push(recipe)
                    }
                }
                process.callback(recipes, null)
            } catch (error:Error) {
                process.callback(null, error.message)
            }
        })
    }

    public function fetchInstances(callback: Function):void {
        var process:GmsaasProcess = new GmsaasProcess(callback)
        var parameters:Vector.<String> = new <String>["instances", "list"]

        executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
            // removeProcess(event)

            var json:Object = handleOutput(process.data, process.callback)
            if (!json) return;

            try {
                var instances:Array = new Array()
                var instancesInfo:Array = json['instances']
                for each (var info:Object in instancesInfo) {
                    var instance:GenymotionSimulator = new GenymotionSimulator(info)
                    instances.push(instance)
                }
                process.callback(instances, null)
            } catch (error:Error) {
                process.callback(null, error.message)
            }
        })
    }

    public function startInstance(recipeUuid:String, instanceName:String, callback:Function):void {
        var process:GmsaasProcess = new GmsaasProcess(callback)
        var parameters:Vector.<String> = new <String>["instances", "start", recipeUuid, instanceName]

        executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
            // removeProcess(event)

            var json:Object = handleOutput(process.data, process.callback)
            if (!json) return;

            try {
                var info:Object = json['instance']
                var instance:GenymotionSimulator = new GenymotionSimulator(info)
                process.callback(instance, null)
            } catch (error:Error) {
                process.callback(null, error.message)
            }
        })
    }

    public function stopInstance(instanceUuid:String, callback:Function):void {
        var process:GmsaasProcess = new GmsaasProcess(callback)
        var parameters:Vector.<String> = new <String>["instances", "stop", instanceUuid]

        executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
            // removeProcess(event)

            var json:Object = handleOutput(process.data, process.callback)
            if (!json) return;

            try {
                var info:Object = json['instance']
                var instance:GenymotionSimulator = new GenymotionSimulator(info)
                process.callback(instance, null)
            } catch (error:Error) {
                process.callback(null, error.message)
            }
        })
    }

    public function adbConnect(instanceUuid:String, callback:Function):void {
        var process:GmsaasProcess = new GmsaasProcess(callback)
        var parameters:Vector.<String> = new <String>["instances", "adbconnect", instanceUuid]

        executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
            // removeProcess(event)

            var json:Object = handleOutput(process.data, process.callback)
            if (!json) return;

            try {
                var info:Object = json['instance']
                var instance:GenymotionSimulator = new GenymotionSimulator(info)
                process.callback(instance, null)
            } catch (error:Error) {
                process.callback(null, error.message)
            }
        })
    }

    public function adbDisconnect(instanceUuid:String, callback:Function):void {
        var process:GmsaasProcess = new GmsaasProcess(callback)
        var parameters:Vector.<String> = new <String>["instances", "adbdisconnect", instanceUuid]

        executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
            // removeProcess(event)

            var json:Object = handleOutput(process.data, process.callback)
            if (!json) return;

            try {
                var info:Object = json['instance']
                var instance:GenymotionSimulator = new GenymotionSimulator(info)
                process.callback(instance, null)
            } catch (error:Error) {
                process.callback(null, error.message)
            }
        })
    }

    public function whoami(callback:Function):void {
        var process:GmsaasProcess = new GmsaasProcess(callback)
        var parameters:Vector.<String> = new <String>["auth", "whoami"]

        executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
            // removeProcess(event)

            var json:Object = handleOutput(process.data, process.callback)
            if (!json) return;

            process.callback(json.auth.email, null)
        })
    }

    public function login(email:String, password:String, callback:Function):void {
        var process:GmsaasProcess = new GmsaasProcess(callback)
        var parameters:Vector.<String> = new <String>["auth", "login", email, password]

        executeProcess(process, parameters,function (event:NativeProcessExitEvent):void {
            // removeProcess(event)

            var json:Object = handleOutput(process.data, process.callback)
            if (!json) return;
            process.callback(json.auth, null)
        })
    }

    public function logout(callback:Function):void {
        var process:GmsaasProcess = new GmsaasProcess(callback)
        var parameters:Vector.<String> = new <String>["auth", "logout"]

        executeProcess(process, parameters, function (event:NativeProcessExitEvent):void {
            // removeProcess(event)

            var json:Object = handleOutput(process.data, process.callback)
            if (!json) return;
            process.callback(json.auth, null)
        })
    }

    // // // //
    // COMMON
    // // // //

    private function executeProcess(process:GmsaasProcess, parameters:Vector.<String>, exitFunction:Function):void {
        var arguments: Vector.<String> = new <String>["--format", "compactjson"]
        arguments = arguments.concat(parameters)

        var processInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        processInfo.executable = gmsaasFile
        processInfo.arguments = arguments

        process.addEventListener(NativeProcessExitEvent.EXIT, exitFunction)
        process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, fetchRecipesDataHandler)
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, fetchRecipesDataHandler)
        processes.push(process)
        process.start(processInfo)
    }

    private function fetchRecipesDataHandler(event:ProgressEvent):void {
        var process:GmsaasProcess = event.currentTarget as GmsaasProcess

        switch (event.type) {
            case ProgressEvent.STANDARD_OUTPUT_DATA:
                process.data += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
                break
            case ProgressEvent.STANDARD_ERROR_DATA:
                process.data += process.standardError.readUTFBytes(process.standardError.bytesAvailable)
                break
        }
    }

    private function handleOutput(outputData:String, callback:Function):Object {
        try {
            var json:Object = JSON.parse(outputData)

            if ('error' in json) {
                callback(null, json.error.message)
                return null
            }

            return json
        } catch (error:Error) {
            callback(null, error.message)
        }

        return null
    }

    private function removeProcess(event:NativeProcessExitEvent):void {
        var process:GmsaasProcess = event.currentTarget as GmsaasProcess
        process.removeEventListener(event.type, arguments.callee)
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, fetchRecipesDataHandler)
        process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, fetchRecipesDataHandler)
    }

    public function stopAllProcesses():void {
        processes.forEach(function(process:GmsaasProcess, index:int, vector:Vector.<GmsaasProcess>):void {
            process.exit(true)
        })
    }
}
}
