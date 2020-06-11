package com.ats.helpers {

public class Version {

    public static const SUPERIOR:int = 1
    public static const EQUALS:int = 0;
    public static const INFERIOR:int = -1;

	[Bindable]
    public var stringValue:String

	public var major:int
	public var minor:int
	public var patch:int

    public function Version(value:String) {
        var array:Array = value.split(".")
        major = parseInt(array[0])
        minor = parseInt(array[1])
        patch = parseInt(array[2])

        stringValue = value
    }

    public function compare(version:Version):int {
        var compareMajor:int = compareIntValues(major, version.major)
        if (compareMajor != EQUALS) {
            return compareMajor
        }

        var compareMinor:int = compareIntValues(minor, version.minor)
        if (compareMinor != EQUALS) {
            return compareMinor
        }

        return EQUALS
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
}
}
