package com.ats.managers.gmsaas {
import flash.events.Event;

public class GmsaasManagerEvent extends Event {

    public static const COMPLETED:String = "GmsaasManagerEventCompleted"
    public static const ERROR:String = "GmsaasManagerEventError"

    public var error: String
    public var data: Array

    public function GmsaasManagerEvent(type:String, data:Array, error:String) {
        super(type);

        this.data = data
        this.error = error
    }
}
}
