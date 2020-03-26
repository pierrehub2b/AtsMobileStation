package helpers {
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;

import mx.core.FlexGlobals;

public class DevicePortSettingsHelper {

    private const portSettingsFile:File = File.userDirectory.resolvePath(".actiontestscript/mobilestation/settings/portSettings.txt");
    public static var shared:DevicePortSettingsHelper = new DevicePortSettingsHelper();

    public function DevicePortSettingsHelper() {
        settings = new Vector.<DevicePortSettings>();

        if (!portSettingsFile.exists) {
            generatePortSettingsFile();
        }

        settings = fetchPortSettings();
    }
    private var settings:Vector.<DevicePortSettings>;

    public function save():void {
        var fileStream:FileStream = new FileStream();
        fileStream.open(portSettingsFile, FileMode.WRITE);
        for each(var devicePortSettings:DevicePortSettings in settings) {
            fileStream.writeUTFBytes(devicePortSettings.toString() + "\n");
        }
        fileStream.close();
    }

    public function getPortOfDevice(deviceId:String):int {
        var setting:DevicePortSettings = getPortSetting(deviceId);
        if (setting == null) {
            return -1
        } else {
            return setting.port;
        }
    }

    public function getPortSetting(deviceId:String):DevicePortSettings {
        for each(var devicePortSettings:DevicePortSettings in settings) {
            if (devicePortSettings.deviceId == deviceId) {
                return devicePortSettings;
            }
        }

        return null;
    }

    public function nextPortAvailable(fromIndex:int = 8080):int {
        var ports:Vector.<int> = getAllPorts();
        while (ports.indexOf(fromIndex) != -1) {
            fromIndex += 1;
        }

        return fromIndex;
    }

    public function portIsAvailable(port:int):Boolean {
        var ports:Vector.<int> = getAllPorts();
        var result:int = ports.indexOf(port);
        return result != -1;
    }

    public function deviceForRegisteredPort(port:int):String {
        for each(var devicePortSettings:DevicePortSettings in settings) {
            if (devicePortSettings.port == port) {
                return devicePortSettings.deviceId;
            }
        }
        return null;
    }

    public function addSettings(setting:DevicePortSettings):void {
        var device:DevicePortSettings = getPortSetting(setting.deviceId);
        var index:int = settings.indexOf(device);

        // remove if exists
        if (index != -1) {
            settings.removeAt(index);
        }

        settings.push(setting);
        updateDeviceSettings(setting);
        save();
    }

    public function removeSettings(setting:DevicePortSettings):void {
        var existingDevice:DevicePortSettings = getPortSetting(setting.deviceId);
        if (existingDevice != null) {
            var index:int = settings.indexOf(existingDevice);
            settings.removeAt(index);
            save();
        }
    }

    private function generatePortSettingsFile():void {
        // read device settings and generate port settings
        var deviceSettingsFile:File = FlexGlobals.topLevelApplication.devicesSettingsFile;

        var fileStream:FileStream = new FileStream();
        fileStream.open(deviceSettingsFile, FileMode.READ);
        var contentString:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
        fileStream.close();

        var lines:Array = contentString.split("\n");
        for each(var item:String in lines) {
            var port:DevicePortSettings = DevicePortSettings.initWithDeviceSettingsString(item);
            if (port != null) {
                settings.push(port);
            }
        }

        // write port settings
        save();
    }

    private function fetchPortSettings():Vector.<DevicePortSettings> {
        var fileStream:FileStream = new FileStream();
        fileStream.open(portSettingsFile, FileMode.READ);
        var contentString:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
        fileStream.close();

        var settings:Vector.<DevicePortSettings> = new Vector.<DevicePortSettings>();
        var lines:Array = contentString.split("\n");
        var generatePortSetting:Function = function (item:String, index:int, array:Array):void {
            var port:DevicePortSettings = DevicePortSettings.initWithPortSettingsString(item);
            if (port != null) {
                settings.push(port);
            }
        };
        lines.forEach(generatePortSetting);

        return settings;
    }

    private function getAllPorts():Vector.<int> {
        var ports:Vector.<int> = new Vector.<int>();
        var mapInt:Function = function (setting:DevicePortSettings, index:int, vector:Vector.<DevicePortSettings>):void {
            ports.push(setting.port);
        };
        settings.forEach(mapInt);
        return ports.sort(0);
    }

    private function updateDeviceSettings(portSettings:DevicePortSettings):void {
        var deviceSettings:DeviceSettings = DeviceSettingsHelper.shared.getSettingsForDevice(portSettings.deviceId);
        deviceSettings.port = portSettings.port;
        DeviceSettingsHelper.shared.save(deviceSettings);
    }
}
}
