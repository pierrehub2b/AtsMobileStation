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
		
		public function IosSimulator(id:String, name:String, version:String, booted:Boolean)
		{
			super(id);
			this.modelName = StringUtil.trim(name);
			this.osVersion = version;
			this.started = booted;
		}
		
		override public function startSim():void
		{
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = xcrunExec;
			procInfo.workingDirectory = File.userDirectory;
			
			var process:NativeProcess = new NativeProcess();
			process.addEventListener(NativeProcessExitEvent.EXIT, onBootExit);
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onBootError);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onBootData);
			
			procInfo.arguments = new <String>["simctl", "bootstatus", id, "-b"];
			process.start(procInfo);
		}
		
		protected function onBootData(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			var error:String = proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
			trace("boot data -> " + error);
		}
		
		protected function onBootError(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			var error:String = proc.standardError.readUTFBytes(proc.standardError.bytesAvailable);
			trace("boot error -> " + error);
		}
		
		protected function onBootExit(ev:NativeProcessExitEvent):void{
			
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onBootExit);
			proc.closeInput();
			proc.exit(true);
			
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
			runningDevice = new IosDevice(id, modelName + " (" + osVersion +")", true, ipAddress);;
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
			
			var pinfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			pinfo.executable = xcrunExec;
			pinfo.workingDirectory = File.userDirectory;
			pinfo.arguments = new <String>["simctl", "shutdown", id];
			
			var proc:NativeProcess = new NativeProcess();
			proc.addEventListener(NativeProcessExitEvent.EXIT, onShutdownExit);
			proc.start(pinfo);
		}
		
		protected function onShutdownExit(ev:NativeProcessExitEvent):void
		{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;
			proc.removeEventListener(NativeProcessExitEvent.EXIT, onShutdownExit);
			
			proc.closeInput();
			proc.exit(true);
			
			statusOff();
		}
	}
}