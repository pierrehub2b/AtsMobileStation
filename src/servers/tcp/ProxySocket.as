package servers.tcp {
import flash.net.Socket;
import flash.utils.ByteArray;

public class ProxySocket {

    public var socket:Socket;
    public var id:int;
    public var data:ByteArray;

    public function ProxySocket() {}
}
}
