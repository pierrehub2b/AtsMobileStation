package device.running
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	public class IosDeviceInfo extends EventDispatcher
	{
		private const mobileDevice:File = File.applicationDirectory.resolvePath("assets/tools/ios/mobiledevice");
		private var argumentsBase:Vector.<String>;
		
		public var id:String;
		//------------------------
		public var name:String;
		public var type:String;
		public var os:String;
		public var model:String;
		//------------------------
		
		private var currentProperty:String;
		private var loadProperties:Vector.<Array> = new <Array>[["name", "DeviceName"], ["type", "DeviceClass"], ["os", "ProductVersion"], ["model", "ProductType"]];
		
		private var proc:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		
		public function IosDeviceInfo(id:String)
		{
			this.id = id;
			this.argumentsBase = new <String>["get_device_prop", "-t", "5", "-u", id];
		}
		
		public function load():void{
			
			if(loadProperties.length > 0){
				var prop:Array = loadProperties.shift();
				currentProperty = prop[0];
				
				procInfo.executable = mobileDevice;
				procInfo.workingDirectory = File.userDirectory;
				procInfo.arguments = argumentsBase.concat(new <String>[prop[1]]);
				prop = null;
				
				proc.addEventListener(NativeProcessExitEvent.EXIT, onReadDataExit);
				proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadData);
				
				proc.start(procInfo);
			}else{
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		protected function onReadData(ev:ProgressEvent):void{
			this[currentProperty] = proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable).replace("\n", "");
		}
		
		protected function onReadDataExit(ev:NativeProcessExitEvent):void
		{
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onReadDataExit);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadData);
			
			proc.closeInput();
			proc.exit(true);
			load();
		}
		
		public function get device():IosDevice{
			return new IosDevice(id, name + " (" + os +")", false, "0.0.0.0");
		}
	}
}