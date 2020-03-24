package helpers {

import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;

public class DeviceSettingsHelper {

    private const deviceSettingsFile:File = File.userDirectory.resolvePath(".actiontestscript/mobilestation/settings/devicesSettings.txt");

    private var settings:Vector.<DeviceSettings>;

    public static var shared:DeviceSettingsHelper = new DeviceSettingsHelper();

    public function DeviceSettingsHelper() {
        if (deviceSettingsFile.exists) {
            this.settings = fetchSettings();
        } else {
            this.settings = new Vector.<DeviceSettings>();
        }
    }

    public function getSettingsForDevice(deviceId:String):DeviceSettings {
        for each(var deviceSettings:DeviceSettings in settings) {
            if (deviceSettings.deviceId == deviceId) {
                return deviceSettings;
            }
        }

        return null;
    }

    public function save(deviceSettings:DeviceSettings):void {
        var existingDeviceSettings:DeviceSettings = getSettingsForDevice(deviceSettings.deviceId);
        if (existingDeviceSettings != null) {
            var index:int = settings.indexOf(existingDeviceSettings);
            settings.removeAt(index)
        }

        settings.push(deviceSettings);
        saveAll();
    }

    private function fetchSettings():Vector.<DeviceSettings> {
        var fileStream:FileStream = new FileStream();
        fileStream.open(deviceSettingsFile, FileMode.READ);
        var contentString:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
        fileStream.close();

        var settings:Vector.<DeviceSettings> = new Vector.<DeviceSettings>();
        var lines:Array = contentString.split("\n");
        for each(var text:String in lines) {
            var deviceSettings:DeviceSettings = DeviceSettings.initFromDeviceSettingsString(text);
            if (deviceSettings != null) {
                settings.push(deviceSettings);
            }
        }

        return settings;
    }

    private function saveAll():void {
        var fileStream:FileStream = new FileStream();
        fileStream.open(deviceSettingsFile, FileMode.WRITE);
        for each(var deviceSettings:DeviceSettings in settings) {
            fileStream.writeUTFBytes(deviceSettings.toString() + "\n");
        }
        fileStream.close();
    }
}
}
