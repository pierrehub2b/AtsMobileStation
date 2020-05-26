package helpers {
import flash.filesystem.File;
import flash.net.SharedObject;

public class Settings {

    private var sharedObject:SharedObject;

    private static var _instance: Settings = new Settings();

    public static function getInstance():Settings {
        return _instance;
    }

    public function Settings() {
        if (_instance) {
            throw new Error("Settings is a singleton and can only be accessed through Settings.getInstance()");
        }

        sharedObject = SharedObject.getLocal("Settings");

        /* androidSDKDirectory
        if (androidSDKDirectory == null) { */
            androidSDKDirectory = File.userDirectory.resolvePath("AppData/Local/Android/Sdk")
        // }
    }

    public function get androidSDKDirectory():File {
        return sharedObject.data.androidSDKDirectory != null ? sharedObject.data.androidSDKDirectory : null
    }

    public function set androidSDKDirectory(value:File):void {
        sharedObject.data.androidSDKDirectory = value
        sharedObject.flush()
    }
}
}
