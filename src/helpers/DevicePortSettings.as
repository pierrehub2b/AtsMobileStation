package helpers {

public class DevicePortSettings {

    public var deviceId:String;
    public var port:int;

    public function DevicePortSettings(deviceId:String, port:int) {
        this.deviceId = deviceId;
        this.port = port;
    }

    public function toString():String {
        return deviceId + "==" + port.toString()
    }

    // constructor with string
    public static function initWithPortSettingsString(dataString:String):DevicePortSettings {
        var array:Array = dataString.split("==");
        if (array.length != 2) {
            return null;
        }

        var deviceId:String = array[0];
        if (deviceId == "") {
            return null;
        }

        var portString:String = array[1];
        if (portString == "") {
            return null;
        }

        var port:int = parseInt(portString);

        return new DevicePortSettings(deviceId, port);
    }

    // constructor with string
    public static function initWithDeviceSettingsString(dataString:String):DevicePortSettings {
        var array:Array = dataString.split("==");
        if (array.length != 2) {
            return null;
        }

        var deviceId:String = array[0];
        if (deviceId == "") {
            return null;
        }

        var parametersString:String = array[1];
        var parameters:Array = parametersString.split(";");
        if (array.length != 3) {
            return null;
        }

        var portString:String = parameters[1];
        if (portString == "") {
            return null;
        }

        var port:int = parseInt(portString);

        return new DevicePortSettings(deviceId, port);
    }
}

}
