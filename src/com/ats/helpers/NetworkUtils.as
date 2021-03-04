package com.ats.helpers {
	
	import flash.net.InterfaceAddress;
	import flash.net.NetworkInfo;
	import flash.net.NetworkInterface;
	
	public final class NetworkUtils {
		
		public static function getClientLocalIpAddress():String {
			var networkInfo:NetworkInfo = NetworkInfo.networkInfo;
			var interfaces:Vector.<NetworkInterface> = networkInfo.findInterfaces();
			var interfaceObj:NetworkInterface;
			var address:InterfaceAddress;
			
			for (var i:int = 0; i < interfaces.length; i++){
				interfaceObj = interfaces[i];
				for (var j:int = 0; j < interfaceObj.addresses.length; j++){
					address = interfaceObj.addresses[j];
					if(address.ipVersion == "IPv4" && address.address != null && address.broadcast != null){
						var addressArray:Array = address.address.split(".");
						var broadcastArray:Array = address.broadcast.split(".");
						if(addressArray.length == 4 && broadcastArray.length == 4 && addressArray[0] == broadcastArray[0] && addressArray[1] == broadcastArray[1] && addressArray[2] == broadcastArray[2]){
							return address.address;
						}
					}
				}
			}
			
			return null;
		}
	}
}