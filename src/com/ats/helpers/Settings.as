package com.ats.helpers {
import flash.errors.IOError;
import flash.events.EventDispatcher;
import flash.filesystem.File;
import flash.system.Capabilities;

public class Settings extends EventDispatcher {

	private static const APP_FOLDER_WINDOWS:String = "AppData/Local";
	private static const APP_FOLDER_MACOS:String = "Library";
	public static const isMacOs:Boolean = Capabilities.os.indexOf("Mac") > -1;
	public static const workAdbFolder:File = File.applicationDirectory.resolvePath("assets/tools/android");
	public static const workFolder:File = File.userDirectory.resolvePath(".atsmobilestation");
	private static const settingsFolder:File = File.userDirectory.resolvePath(".actiontestscript/mobilestation/settings");
	private static var _instance:Settings = new Settings();

	public static function get defaultAppFolder():File {
		return isMacOs ? File.userDirectory.resolvePath(APP_FOLDER_MACOS) : File.userDirectory.resolvePath(APP_FOLDER_WINDOWS)
	}

	public static function get logsFolder():File {
		return workFolder.resolvePath("logs");
	}

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
		return workAdbFolder.resolvePath("adb" + (isMacOs ? "" : ".exe"))
	}

	public static function getInstance():Settings {
		return _instance;
	}

	public static function cleanLogs():void {

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

	public function Settings() {
		if (_instance) {
			throw new Error("Settings is a singleton and can only be accessed through Settings.getInstance()");
		}
	}
}
}