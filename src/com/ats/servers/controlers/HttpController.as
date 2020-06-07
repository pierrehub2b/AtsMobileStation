package com.ats.servers.controlers {

public class HttpController {

    private var _route:String

    public function get route():String {
        return _route
    }

    public function HttpController(route:String) {
        _route = route
    }

    public function getAll():String { return "" }

    public static function responseNotFound():String
    {
        return response(404, "Not Found")
    }

    protected static function responseSuccess(content:String, mimeType:String = "text/html"):String
    {
        return response(200, "OK", content, mimeType)
    }

    protected static function response(code:int, message:String = "", content:String = "", mimeType:String = "text/html"):String
    {
        return header(code, message, mimeType) + content
    }

    protected static function header(code:int, message:String = "", mimeType:String = "text/html"):String
    {
        return "HTTP/1.1 " + code.toString() + " " + message + "\n" + "Content-Type: " + mimeType + "\n\n"
    }
}
}
