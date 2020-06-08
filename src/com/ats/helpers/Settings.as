package com.ats.helpers {
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	import flash.net.SharedObject;
	import flash.system.Capabilities;
	
	public class Settings extends EventDispatcher {
		
		private static const APP_FOLDER_WINDOWS:String = "AppData/Local";
		private static const APP_FOLDER_MACOS:String = "Library";
		
		public static const isMacOs:Boolean = Capabilities.os.indexOf("Mac") > -1;
		
		public static function get defaultAppFolder():File{
			return isMacOs?File.userDirectory.resolvePath(APP_FOLDER_MACOS):File.userDirectory.resolvePath(APP_FOLDER_WINDOWS)
		}
		
		private var sharedObject:SharedObject;
		
		private static var _instance: Settings = new Settings();
		
		public static function getInstance():Settings {
			return _instance;
		}
		
		private var _androidSdkPath:String;
		private var _pythonPath:String;
		
		public function Settings() {
			if (_instance) {
				throw new Error("Settings is a singleton and can only be accessed through Settings.getInstance()");
			}
			
			sharedObject = SharedObject.getLocal("settings");
			
			androidSdkPath = sharedObject.data.androidSdkPath;
			if(androidSdkPath == null){
				androidSdkFolder = defaultAppFolder.resolvePath("Android").resolvePath("sdk");
			}
			
			pythonPath = sharedObject.data.pythonPath;
			if(pythonPath == null){
				pythonFolder = defaultAppFolder.resolvePath("python");
			}
		}
		
		[Bindable(event="androidSdkPathChange")]
		public function get androidSdkPath():String
		{
			return _androidSdkPath;
		}
		
		public function set androidSdkPath(value:String):void
		{
			if( _androidSdkPath !== value)
			{
				_androidSdkPath = value;
				dispatchEvent(new Event("androidSdkPathChange"));
			}
		}
		
		public function get androidSdkFolder():File {
			return new File(androidSdkPath);
		}
		
		public function set androidSdkFolder(value:File):void {
			
			if(value.exists){
				androidSdkPath = value.nativePath;
			}else{
				androidSdkPath = null;
			}
			
			sharedObject.data.androidSdkPath = androidSdkPath
			sharedObject.flush()
		}
		
		[Bindable(event="pythonPathChange")]
		public function get pythonPath():String
		{
			return _pythonPath;
		}
		
		public function set pythonPath(value:String):void
		{
			if( _pythonPath !== value)
			{
				_pythonPath = value;
				dispatchEvent(new Event("pythonPathChange"));
			}
		}
		
		public function get pythonFolder():File {
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
		}
	}
}