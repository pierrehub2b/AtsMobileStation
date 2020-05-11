package servers.http {

import flash.desktop.NativeApplication;
import flash.events.Event;
import flash.events.ProgressEvent;
import flash.events.ServerSocketConnectEvent;
import flash.net.ServerSocket;
import flash.net.Socket;
import flash.utils.ByteArray;

import servers.http.controllers.HttpController;
import servers.http.controllers.DeviceController;

public class HttpServer {

    private var _server:ServerSocket
    private var _controllers:Object = new Object()

    private var _errorCallback:Function = null

    private static var _instance: HttpServer = new HttpServer();

    /** Return singleton instance. */
    public static function getInstance():HttpServer {
        return _instance;
    }

    public function HttpServer() {
        NativeApplication.nativeApplication.addEventListener(Event.EXITING, applicationExitHandler, false, 0, true);

        registerController(new DeviceController())
    }

    private function applicationExitHandler(event:Event) {
        _server.removeEventListener(ServerSocketConnectEvent.CONNECT, onConnect)
        _server.close()
    }

    private function registerController(controller: HttpController) {
        if (_instance) {
            throw new Error("Singleton is a singleton and can only be accessed through HttpServer.getInstance()");
        }

        _controllers[controller.route] = controller
    }

    public function listen(port:int, errorCallback:Function = null):void
    {
        _errorCallback = errorCallback

        try {
            _server = new ServerSocket()
            _server.addEventListener(ServerSocketConnectEvent.CONNECT, onConnect, false, 0, true)
            _server.bind(port)
            _server.listen()
        } catch (e: Error) {
            if (errorCallback != null) {
                errorCallback(e)
            }
        }
    }

    private function onConnect(event:ServerSocketConnectEvent) {
        var socket = event.socket
        socket.addEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData, false, 0, true)
    }

    private function onClientSocketData(event:ProgressEvent) {
        var socket = event.target as Socket
        socket.removeEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData)

        var bytes:ByteArray = new ByteArray()

        socket.readBytes(bytes)
        var request:String = bytes.toString();
        var url:String = request.substring(4, request.indexOf("HTTP/") - 1);

        var urlPattern:RegExp = /(.*)\/([^\?]*)\??(.*)$/
        var action:String = url.replace(urlPattern, "$2")

        var controller:HttpController = _controllers[action]

        if (controller) {
            socket.writeUTFBytes(controller.getAll())
        } else {
            socket.writeUTFBytes(HttpController.responseNotFound())
        }

        socket.flush();
        socket.close();
    }
}
}
