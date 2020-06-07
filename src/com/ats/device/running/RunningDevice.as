package com.ats.device.running
{
import com.ats.device.*;

import avmplus.getQualifiedClassName;

import com.ats.device.running.AndroidDevice;

import mx.utils.UIDUtil;

[Bindable]
[RemoteClass(alias="device.RunningDevice")]
public class RunningDevice extends Device
{
	public var locked:String = null;
	public var booted:Boolean = true;
	public var authorized:Boolean = true
	public var ip:String;// = "";
	public var port:String = "";

	public var runningId:String = UIDUtil.createUID();

	[Transient]public var settingsPort:String = "";
	[Transient]public var automaticPort:Boolean = true;
	[Transient]public var error:String = null;
	[Transient]public var errorMessage:String = "";
	[Transient]public var usbMode:Boolean = false;
	[Transient]public var udpIpAddress:String;

	public function RunningDevice(id:String=""){
		super(id);
		tooltip = "Starting driver ...";
		trace("Starting driver -> " + getQualifiedClassName(this));
	}

	public function start():void{}

	public function get monaDevice():Object {
		return {
			id: runningId,
			ip: ip,
			port: port,
			locked: locked,
			manufacturer: manufacturer,
			modelId: modelId,
			modelName: modelName,
			osVersion: osVersion,
			sdkVersion: (this is AndroidDevice) ? (this as AndroidDevice).androidSdk : null,
			status: status
		}
	}

	protected function installing():void{
		status = INSTALL;
		tooltip = "Installing driver ...";
		trace("Installing driver -> " + getQualifiedClassName(this));
	}

	protected function waiting():void{
		status = WAITING_FOR_DEVICE;
		tooltip = "Waiting for ...";
		trace("Waiting for device -> " + getQualifiedClassName(this));
	}

	protected function started():void{
		status = READY;
		tooltip = "Driver started and ready";
		trace("Driver started -> " + getQualifiedClassName(this));
	}

	protected function failed():void{
		status = FAIL;
		tooltip = "Driver can not be started";
		trace("Driver error" + getQualifiedClassName(this));
	}

	protected function usbError(error:String):void {
		status = USB_ERROR;
		errorMessage = " - " + error;
		tooltip = "Problem when installing driver ...";
		trace("USB install error" + getQualifiedClassName(this));
	}
}
}