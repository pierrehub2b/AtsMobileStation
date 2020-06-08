package com.ats.servers.controlers {

public class DeviceController extends HttpController {

    public function DeviceController() {
        super('devices')
    }

    override public function getAll():String {
        var devices: Array = RunningDevicesManager.getInstance().collection.toArray()

        /* for each (var device:RunningDevice in devices) {
            var deviceInfo:Object = new Object()
            deviceInfo['id'] = device.id
        } */

        var json:String = JSON.stringify(devices)
        return responseSuccess(json, "application/json");
    }
}
}
