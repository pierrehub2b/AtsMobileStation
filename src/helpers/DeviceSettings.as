package helpers {

public class DeviceSettings {

    public var deviceId:String;
    public var automaticPort:Boolean;
    public var usbMode:Boolean;
    public var port:int; // -1 == null

    public function DeviceSettings(deviceId:String, automaticPort:Boolean = true, usbMode:Boolean = false, port:int = 8080) {
        this.deviceId = deviceId.toLowerCase();
        this.automaticPort = automaticPort;
        this.usbMode = usbMode;
        this.port = port;
    }

    public function toString():String {
        return deviceId + "==" + automaticPort.toString() + ";" + (port == -1 ? "" : port.toString()) + ";" + usbMode.toString();
    }

    // custom init
    public static function initFromDeviceSettingsString(string:String):DeviceSettings {
        var array:Array = string.split("==");
        if (array.length != 2) {
            return null;
        }

        var deviceId:String = array[0];
        if (deviceId == "") {
            return null;
        }

        var parametersString:String = array[1];
        var parameters:Array = parametersString.split(";");
        if (parameters.length != 3) {
            return null;
        }

        var automaticPortStringValue:String = parameters[0];
        var automaticPort:Boolean = automaticPortStringValue == "true";

        var portStringValue:String = parameters[1];
        var port:int = portStringValue == "" ? -1 : parseInt(portStringValue);

        var usbModeStringValue:String = parameters[2];
        var usbMode:Boolean = usbModeStringValue == "true";

        return new DeviceSettings(deviceId, automaticPort, usbMode, port);
    }
}
}
