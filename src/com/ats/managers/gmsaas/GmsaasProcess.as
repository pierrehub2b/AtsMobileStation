package com.ats.managers.gmsaas {
import flash.desktop.NativeProcess;

public class GmsaasProcess extends NativeProcess {

    public var callback:Function
    public var data:String

    public function GmsaasProcess(callback:Function) {
        this.callback = callback
        this.data = ""
    }
}
}
