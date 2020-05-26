package 
{
import device.simulator.AndroidSimulator;

import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.system.Capabilities;

import helpers.Settings;

import mx.collections.ArrayCollection;
	
	import device.simulator.IosSimulator;

import mx.utils.UIDUtil;

public class AvailableSimulatorsManager extends EventDispatcher
	{
		public static const COLLECTION_CHANGED:String = "collectionChanged";
		
		private const regex:RegExp = /(.*)\(([^\)]*)\).*\[(.*)\](.*)/;
		private const jsonPattern:RegExp = /\{[^]*\}/;
		private const iosVersionReplacmentPattern:RegExp = /-/g; 
		
		private var output:String = "";
		
		[Bindable]
		public var info:String = "";
			
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		private var process: NativeProcess;
		private var procInfo: NativeProcessStartupInfo;
		
		public function AvailableSimulatorsManager()
		{
			info = "Loading simulators, please wait ...";

			if (Capabilities.os.indexOf("Mac") > -1) {
				fetchIosSimulators()
			}

			fetchAndroidEmulators()
		}

		protected function fetchIosSimulators():void {
			procInfo = new NativeProcessStartupInfo();
			process = new NativeProcess();

			procInfo.executable = new File("/usr/bin/env");
			procInfo.workingDirectory = File.userDirectory;

			process.addEventListener(NativeProcessExitEvent.EXIT, onSetupSimulatorExit, false, 0, true);

			procInfo.arguments = new <String>["defaults", "write" ,"com.apple.iphonesimulator", "ShowChrome", "-int", "0"];
			process.start(procInfo);
		}
		
		protected function onSetupSimulatorExit(ev:NativeProcessExitEvent):void
		{
			process = ev.currentTarget as NativeProcess;
			process.removeEventListener(NativeProcessExitEvent.EXIT, onSetupSimulatorExit);
			
			process.closeInput();
			process.exit(true);
			
			procInfo = new NativeProcessStartupInfo();
			process = new NativeProcess();
			
			procInfo.executable = new File("/usr/bin/env");
			procInfo.workingDirectory = File.userDirectory;
			
			output = "";
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist, false, 0, true);
			
			procInfo.arguments = new <String>["xcrun", "simctl", "list", "devices", "-j"];
			process.start(procInfo);
			procInfo = null;
		}
		
		protected function onProcessOutput(ev:ProgressEvent):void{
			process = ev.currentTarget as NativeProcess;
			output = output.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onSimCtlExist(ev:NativeProcessExitEvent):void
		{
			process = ev.currentTarget as NativeProcess;
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist);
			
			process.closeInput();
			process.exit(true);
			process = null;
			
			var obj:Object;
			if(output.length > 0) {
				var data:Array = jsonPattern.exec(output);
				if(data != null && data.length > 0){
					
					obj = JSON.parse(data[0]);
					var devices:Object = obj["devices"];
					
					for (var runtime:Object in devices) {
						var iosVersion:String = runtime.toString().split(".")[runtime.toString().split(".").length-1].replace(iosVersionReplacmentPattern, ".");
						for (var d:Object in devices[runtime]) {
							var device:Object = devices[runtime][d];
							if(device["name"].indexOf("iPhone") == 0 && device["isAvailable"] && iosVersion.indexOf("iOS") > -1) {
								collection.addItem(new IosSimulator(device["udid"], device["name"], iosVersion.replace("iOS.",""), device["state"] == "Booted"));
							}
							device = null;
						}
						d = null;
					}
					devices = null;
					runtime = null;					
				}
				
				if (collection.length == 0) {
					info = String("No simulators found !\n(Xcode may not be installed on this station !)");
				} else {
					info = String("");
				}
			}			
		}

		private var emulatorProcess:NativeProcess
		private var emulatorOutputData:String
		private var emulatorErrorData:String

		protected function fetchAndroidEmulators(callback:Function = null) {
			var file = Settings.getInstance().androidSDKDirectory.resolvePath("emulator/emulator")
			if (!file.exists) {
				trace("No Android SDK configured")
				return
			}

			var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
			info.executable = file
			info.arguments = new <String>["-list-avds"];

			emulatorProcess = new NativeProcess()
			emulatorProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData, false, 0, true);
			emulatorProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData, false, 0, true);
			emulatorProcess.addEventListener(NativeProcessExitEvent.EXIT, onExit, false, 0, true);
			emulatorProcess.start(info)
		}

		private function onOutputData(event:ProgressEvent):void {
			emulatorOutputData = emulatorProcess.standardOutput.readUTFBytes(emulatorProcess.standardOutput.bytesAvailable)
		}

		private function onErrorData(event:ProgressEvent):void {
			emulatorOutputData = emulatorProcess.standardError.readUTFBytes(emulatorProcess.standardError.bytesAvailable)
		}

		private function onExit(event:NativeProcessExitEvent):void {
			emulatorProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
			emulatorProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
			emulatorProcess.removeEventListener(NativeProcessExitEvent.EXIT, onExit);

			if (emulatorErrorData != null) {
				// handle error
				return
			}

			// handle data
			var lines:Array
			if (Capabilities.os.indexOf("Mac") > -1) {
				lines = emulatorOutputData.split("\n")
			} else {
				lines = emulatorOutputData.split("\n\r")
			}

			for each (var line:String in lines) {
				if (line) {
					collection.addItem(new AndroidSimulator(line));
				}
			}
		}
	}
}