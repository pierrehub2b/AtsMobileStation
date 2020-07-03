package com.ats.helpers {
import flash.errors.IOError;
import flash.events.EventDispatcher;
import flash.filesystem.File;
import flash.net.SharedObject;
import flash.system.Capabilities;

public class Settings extends EventDispatcher {
		
		private static var _instance: Settings = new Settings();
		
		private static const APP_FOLDER_WINDOWS:String = "AppData/Local";
		private static const APP_FOLDER_MACOS:String = "Library";
		
		public static const isMacOs:Boolean = Capabilities.os.indexOf("Mac") > -1;
		public static const workAdbFolder:File = File.applicationDirectory.resolvePath("assets/tools/android");
		public static const workFolder:File = File.userDirectory.resolvePath(".atsmobilestation");
		
		public static function get defaultAppFolder():File{
			return isMacOs?File.userDirectory.resolvePath(APP_FOLDER_MACOS):File.userDirectory.resolvePath(APP_FOLDER_WINDOWS)
		}

		public static function get logsFolder():File {
			return workFolder.resolvePath("logs");
		}
		
		private static const settingsFolder:File = File.userDirectory.resolvePath(".actiontestscript/mobilestation/settings");
		
		public static function get devicesSettingsFile():File {
			return settingsFolder.resolvePath("devicesSettings.txt");
		}
		
		public static function get devicePortSettingsFile():File {
			return settingsFolder.resolvePath("portSettings.txt");
		}
		
		public static function get settingsFile():File {
			return settingsFolder.resolvePath("settings.txt");
		}
		
		public static function get adbFile():File {
			if(isMacOs){
				return workAdbFolder.resolvePath("adb");
			}else{
				return workAdbFolder.resolvePath("adb.exe");
			}
		}
		
		public static function cleanLogs():void{
			
			try {
				logsFolder.deleteDirectory(true);
			} catch (err:IOError) {
			}
			
			var date:Date = new Date(2020, 2, 31, 18, 30, 0, 0);
			if (devicePortSettingsFile.exists && devicePortSettingsFile.modificationDate < date) {
				devicePortSettingsFile.deleteFile();
			}
			
			if (devicesSettingsFile.exists && devicesSettingsFile.modificationDate < date) {
				devicesSettingsFile.deleteFile();
			}
		}
				
			
		public static function getInstance():Settings {
			return _instance;
		}
		
		private var sharedObject:SharedObject;
		private var _androidSdkPath:String;
		//private var _pythonPath:String;
		
		public function Settings() {
			if (_instance) {
				throw new Error("Settings is a singleton and can only be accessed through Settings.getInstance()");
			}
			
			sharedObject = SharedObject.getLocal("settings");
			
			//pythonPath = sharedObject.data.pythonPath;
			//if(pythonPath == null){
			//	pythonFolder = defaultAppFolder.resolvePath("python");
			//}
		}
		
		//[Bindable(event="pythonPathChange")]
		//public function get pythonPath():String
		//{
		//	return _pythonPath;
		//}
		
		//public function set pythonPath(value:String):void
		//{
		//	if( _pythonPath !== value)
		//	{
		//		_pythonPath = value;
		//		dispatchEvent(new Event("pythonPathChange"));
		//	}
		//}
		
		/*public function get gmsaasExecutable():File {
			const pyth:File = pythonFolder;
			if(pyth != null && pyth.exists){
				const gm:File = pyth.resolvePath("Scripts").resolvePath(GmsaasInstaller.gmsaasFileName);
				if(gm.exists){
					return gm;
				}
			}
			return null;
		}*/
		
		/*public function get pythonFolder():File {
			if (!pythonPath) {
				return null
			}
			return new File(pythonPath);
		}
		
		public function set pythonFolder(value:File):void {
			
			if(value.exists){
				pythonPath = value.nativePath;
			}else{
				pythonPath = null;
			}
			
			sharedObject.data.pythonPath = pythonPath
			sharedObject.flush()
		}*/
	}
}