package com.ats.managers.gmsaas {
import flash.events.Event;

public class GmsaasInstallerProgressEvent extends Event {

    public static const PROGRESS:String = "GmsaasInstallerProgress"

    public var state:String

    public function GmsaasInstallerProgressEvent(state:String) {
        super(PROGRESS);

        this.state = state
    }
}
}
