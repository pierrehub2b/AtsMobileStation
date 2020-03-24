package device.simulator
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.net.InterfaceAddress;
	import flash.net.NetworkInfo;
	import flash.net.NetworkInterface;
	
	import mx.utils.StringUtil;
	
	import device.Device;
	import device.running.IosDevice;
	
	public class IosSimulator extends Simulator
	{
		private const xcrunExec:File = new File("/usr/bin/xcrun");
		private var runningDevice:IosDevice;
		private var process:NativeProcess;
		private var procInfo: NativeProcessStartupInfo;
		
		public function IosSimulator(id:String, name:String, version:String, booted:Boolean)
		{
			super(id);
			this.modelName = StringUtil.trim(name);
			this.osVersion = version;
			this.started = booted;
		}
		
		override public function startSim():void
		{
			procInfo = new NativeProcessStartupInfo();
			procInfo.executable = xcrunExec;
			procInfo.workingDirectory = File.userDirectory;
			
			process = new NativeProcess();
			process.addEventListener(NativeProcessExitEvent.EXIT, onBootExit);
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onBootError);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onBootData);
			
			procInfo.arguments = new <String>["simctl", "bootstatus", id, "-b"];
			process.start(procInfo);
		}
		
		protected function onBootData(ev:ProgressEvent):void{
			process = ev.currentTarget as NativeProcess;
			var error:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
			trace("boot data -> " + error);
		}
		
		protected function onBootError(ev:ProgressEvent):void{
			process = ev.currentTarget as NativeProcess;
			var error:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			trace("boot error -> " + error);
		}
		
		protected function onBootExit(ev:NativeProcessExitEvent):void{
			
			process = ev.currentTarget as NativeProcess;
			process.removeEventListener(NativeProcessExitEvent.EXIT, onBootExit);
			process.closeInput();
			process.exit(true);
			process = null;
			procInfo = null;
			statusOn();
		}
		
		public function get device():IosDevice{
			var ipAddress:String = "---";
			var netInterfaces:Vector.<NetworkInterface> = NetworkInfo.networkInfo.findInterfaces();
			if(netInterfaces.length > 1)
			{
				var addresses:Vector.<InterfaceAddress> = netInterfaces[1].addresses;
				for each(var intAddress:InterfaceAddress in addresses)
				{
					ipAddress = intAddress.address;
					if(intAddress.ipVersion == "IPv4"){
						break;
					}
				}
			}
			runningDevice = new IosDevice(id, modelName + " (" + osVersion +")", true, ipAddress);
			return runningDevice;
		}
		
		override public function stopSim():void
		{
			runningDevice.addEventListener(Device.STOPPED_EVENT, deviceStoppedHandler, false, 0, true);
			runningDevice.close();
		}
		
		public function deviceStoppedHandler(ev:Event):void{
			
			runningDevice.removeEventListener(Device.STOPPED_EVENT, deviceStoppedHandler);
			runningDevice = null;
			
			procInfo = new NativeProcessStartupInfo();
			procInfo.executable = xcrunExec;
			procInfo.workingDirectory = File.userDirectory;
			procInfo.arguments = new <String>["simctl", "shutdown", id];
			
			process = new NativeProcess();
			process.addEventListener(NativeProcessExitEvent.EXIT, onShutdownExit);
			process.start(procInfo);
		}
		
		protected function onShutdownExit(ev:NativeProcessExitEvent):void
		{
			process = ev.currentTarget as NativeProcess;
			process.removeEventListener(NativeProcessExitEvent.EXIT, onShutdownExit);
			
			process.closeInput();
			process.exit(true);
			process = null;
			procInfo = null;
			statusOff();
		}
	}
}