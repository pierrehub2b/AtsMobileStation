package com.ats.managers
{
import com.ats.device.simulator.AndroidSimulator;

import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.system.Capabilities;

import com.ats.helpers.Settings;

import mx.collections.ArrayCollection;
	
	import com.ats.device.simulator.IosSimulator;

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
		
		private var iosProcess: NativeProcess;
		private var androidProcess: NativeProcess;

		public function AvailableSimulatorsManager()
		{
			info = "Loading simulators, please wait ...";

			if (Capabilities.os.indexOf("Mac") > -1) {
				fetchIosSimulators()
			}

			fetchAndroidEmulators()
		}
		
		public function terminate():void{
			if (iosProcess != null && iosProcess.running) {
				iosProcess.exit(true);
			}
			
			if (androidProcess != null && androidProcess.running) {
				androidProcess.exit(true);
			}
		}

		protected function fetchIosSimulators():void {
			var nativeProcessStartupInfo: NativeProcessStartupInfo = new NativeProcessStartupInfo();
			nativeProcessStartupInfo.executable = new File("/usr/bin/env");
			nativeProcessStartupInfo.workingDirectory = File.userDirectory;
			nativeProcessStartupInfo.arguments = new <String>["defaults", "write" ,"com.apple.iphonesimulator", "ShowChrome", "-int", "0"];

			iosProcess = new NativeProcess();
			iosProcess.addEventListener(NativeProcessExitEvent.EXIT, onSetupSimulatorExit, false, 0, true);
			iosProcess.start(nativeProcessStartupInfo);
		}
		
		protected function onSetupSimulatorExit(ev:NativeProcessExitEvent):void
		{
			iosProcess = ev.currentTarget as NativeProcess;
			iosProcess.removeEventListener(NativeProcessExitEvent.EXIT, onSetupSimulatorExit);
			
			iosProcess.closeInput();
			iosProcess.exit(true);

			output = "";

			var nativeProcessStartupInfo: NativeProcessStartupInfo = new NativeProcessStartupInfo();
			nativeProcessStartupInfo.executable = new File("/usr/bin/env");
			nativeProcessStartupInfo.workingDirectory = File.userDirectory;
			nativeProcessStartupInfo.arguments = new <String>["xcrun", "simctl", "list", "devices", "-j"];

			iosProcess = new NativeProcess();
			iosProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput, false, 0, true);
			iosProcess.addEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist, false, 0, true);
			iosProcess.start(nativeProcessStartupInfo);
		}
		
		protected function onProcessOutput(ev:ProgressEvent):void{
			iosProcess = ev.currentTarget as NativeProcess;
			output = output.concat(iosProcess.standardOutput.readUTFBytes(iosProcess.standardOutput.bytesAvailable));
		}
		
		protected function onSimCtlExist(ev:NativeProcessExitEvent):void
		{
			iosProcess = ev.currentTarget as NativeProcess;
			iosProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onProcessOutput);
			iosProcess.removeEventListener(NativeProcessExitEvent.EXIT, onSimCtlExist);
			
			iosProcess.closeInput();
			iosProcess.exit(true);
			iosProcess = null;
			
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
					info = "No simulators found !\n(Xcode may not be installed on this station !)";
				} else {
					info = "";
				}
			}			
		}

		private var emulatorOutputData:String
		private var emulatorErrorData:String

		protected function fetchAndroidEmulators(callback:Function = null):void {
			var file:File
			if (Capabilities.os.indexOf("Mac") > -1) {
				file = File.userDirectory.resolvePath("Library/Android/sdk/emulator/emulator")
			} else {
				file = File.userDirectory.resolvePath("AppData/Local/Android/Sdk/emulator/emulator.exe")
			}

			if (!file.exists) {
				trace("No Android SDK configured")
				return
			}

			var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
			info.executable = file
			info.arguments = new <String>["-list-avds"];

			androidProcess = new NativeProcess()
			androidProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData, false, 0, true);
			androidProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData, false, 0, true);
			androidProcess.addEventListener(NativeProcessExitEvent.EXIT, onExit, false, 0, true);
			androidProcess.start(info)
		}

		private function onOutputData(event:ProgressEvent):void {
			var process: NativeProcess = event.currentTarget as NativeProcess
			emulatorOutputData = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
		}

		private function onErrorData(event:ProgressEvent):void {
			var process: NativeProcess = event.currentTarget as NativeProcess
			emulatorOutputData = process.standardError.readUTFBytes(process.standardError.bytesAvailable)
		}

		private function onExit(event:NativeProcessExitEvent):void {
			var process: NativeProcess = event.currentTarget as NativeProcess
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onExit);

			if (emulatorErrorData != null || emulatorOutputData == null) {
				// handle error
				return
			}

			// handle data
			var lines:Array
			if (Capabilities.os.indexOf("Mac") > -1) {
				lines = emulatorOutputData.split("\n")
			} else {
				lines = emulatorOutputData.split("\r\n")
			}

			for each (var line:String in lines) {
				if (line) {
					collection.addItem(new AndroidSimulator(line));
				}
			}
		}
	}
}