package com.ats.helpers {

public class Version {

    public static const SUPERIOR:int = 1
    public static const EQUALS:int = 0;
    public static const INFERIOR:int = -1;

    private var _stringValue:String

    private var _major:int
    private var _minor:int
    private var _patch:int

    public function Version(value:String) {
        var array:Array = value.split(".")
        _major = parseInt(array[0])
        _minor = parseInt(array[1])
        _patch = parseInt(array[2])

        _stringValue = value
    }

    public function compare(version:Version):int {
        var compareMajor:int = compareIntValues(_major, version.major)
        if (compareMajor != EQUALS) {
            return compareMajor
        }

        var compareMinor:int = compareIntValues(_minor, version.minor)
        if (compareMinor != EQUALS) {
            return compareMinor
        }

        return compareIntValues(_patch, patch)
    }

    private function compareIntValues(a:int, b:int):int {
        if (a < b) {
            return INFERIOR
        } else if (a > b) {
            return SUPERIOR
        } else {
            return EQUALS
        }
    }

    public function get stringValue():String {
        return _stringValue;
    }

    public function get major():int {
        return _major
    }

    public function get minor():int {
        return _minor
    }

    public function get patch():int {
        return _patch
    }
}
}
