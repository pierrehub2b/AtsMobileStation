package com.ats.managers.gmsaas {
import com.ats.gui.alert.CredentialsAlert;
import com.ats.helpers.Settings;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.EventDispatcher;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

import mx.core.FlexGlobals;
import mx.managers.PopUpManager;

public class GmsaasInstaller extends EventDispatcher {

    public static const GMSAAS_INSTALLER_STATE_INSTALLING_PIP:String = "Installing PIP"
    public static const GMSAAS_INSTALLER_STATE_INSTALLING_GMSAAS:String = "Installing GMSAAS"
    public static const GMSAAS_INSTALLER_STATE_ASKING_CREDENTIALS:String = "Asking credentials"
    public static const GMSAAS_INSTALLER_STATE_INSTALL_COMPLETED:String = "GMSAAS confirguration completed"
    public static const GMSAAS_INSTALLER_STATE_UNINSTALLING:String = "Uninstalling GMSAAS"
    public static const GMSAAS_INSTALLER_STATE_UNINSTALL_COMPLETED:String = "GMSAAS Uninstall completed"

    private static const pythonFolder:File = Settings.getInstance().pythonFolder

    private static const pythonFileName:String = "python.exe"
    private static const pipFileName:String = "pip3.exe"
    private static const gmsaasFileName:String = "gmsaas.exe"

    private var pythonFile:File
    private var gmsaasFile:File

    static public function isInstalled():Boolean {
        if (!pythonFolder) {
            return false;
        }

        return pythonFolder.resolvePath("Scripts").resolvePath(gmsaasFileName).exists
    }

    public function install():void {
        if (Settings.isMacOs) {
            dispatchEvent(new GmsaasInstallerErrorEvent("MacOS not supported yet"))
            return
        }

        if (!pythonFolder) {
            dispatchEvent(new GmsaasInstallerErrorEvent("Python folder path not set"))
            return
        }

        pythonFile = pythonFolder.resolvePath(pythonFileName);
        if (!pythonFile.exists) {
            dispatchEvent(new GmsaasInstallerErrorEvent("Python file not found"))
            return
        }

        upgradePip()
    }

    private function upgradePip():void {
        dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_INSTALLING_PIP))

        var args:Vector.<String> = new Vector.<String>();
        args.push("-m");
        args.push("pip");
        args.push("install");
        args.push("--upgrade");
        args.push("pip");

        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
        procInfo.executable = pythonFile;
        procInfo.arguments = args;

        var proc:NativeProcess = new NativeProcess();
        proc.addEventListener(NativeProcessExitEvent.EXIT, upgradePipExit);
        proc.start(procInfo);
    }

    private function upgradePipExit(event:NativeProcessExitEvent):void {
        var proc:NativeProcess = event.currentTarget as NativeProcess
        proc.removeEventListener(NativeProcessExitEvent.EXIT, upgradePipExit);

        var pipFile:File = pythonFolder.resolvePath("Scripts").resolvePath(pipFileName);
        if (!pipFile.exists) {
            dispatchEvent(new GmsaasInstallerErrorEvent("PIP file not found"))
            return
        }

        dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_INSTALLING_GMSAAS))

        var args:Vector.<String> = new Vector.<String>();
        args.push("install");
        args.push("--upgrade");
        args.push("gmsaas");

        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
        procInfo.executable = pipFile;
        procInfo.arguments = args;

        var newProc:NativeProcess = new NativeProcess();
        newProc.addEventListener(NativeProcessExitEvent.EXIT, gmInstallExit);
        newProc.start(procInfo);
    }

    private function gmInstallExit(event:NativeProcessExitEvent):void {
        var proc:NativeProcess = event.currentTarget as NativeProcess
        proc.removeEventListener(NativeProcessExitEvent.EXIT, gmInstallExit);

        gmsaasFile = pythonFolder.resolvePath("Scripts").resolvePath(gmsaasFileName);
        if (!gmsaasFile.exists) {
            dispatchEvent(new GmsaasInstallerErrorEvent("GMSAAS file not found"))
            return
        }

        dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_ASKING_CREDENTIALS))

        defineJSONOutputFormat()
        defineAndroidSdk()

        presentCredentialsAlert()
    }

    private function defineAndroidSdk():void {
        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
        procInfo.executable = gmsaasFile;
        procInfo.arguments = new <String>["config", "set", "android-sdk-path", Settings.workAdbFolder.nativePath];

        var proc:NativeProcess = new NativeProcess();
        proc.start(procInfo);
    }

    private function defineJSONOutputFormat():void {
        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
        procInfo.executable = gmsaasFile;
        procInfo.arguments = new <String>["config", "set", "output-format", "compactjson"];

        var proc:NativeProcess = new NativeProcess();
        proc.start(procInfo);
    }

    public function presentCredentialsAlert():void {
        const credentialsAlert:CredentialsAlert = new CredentialsAlert();
        credentialsAlert.successCallback = credentialsCompleteHandler
        credentialsAlert.cancelCallback = credentialsCancelHandler

        PopUpManager.addPopUp(credentialsAlert, FlexGlobals.topLevelApplication as AtsMobileStation);
        PopUpManager.centerPopUp(credentialsAlert);
    }

    public function credentialsCompleteHandler(alert:CredentialsAlert):void {
        PopUpManager.removePopUp(alert)

        dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_INSTALL_COMPLETED))
    }

    public function credentialsCancelHandler(alert:CredentialsAlert):void {
        PopUpManager.removePopUp(alert)

        uninstall()
    }

    public function uninstall():void {
        var pipFile:File = pythonFolder.resolvePath("Scripts").resolvePath(pipFileName);
        if (!pipFile.exists) {
            dispatchEvent(new GmsaasInstallerErrorEvent("PIP file not found"))
            return
        }

        dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_UNINSTALLING))

        var args:Vector.<String> = new Vector.<String>();
        args.push("uninstall");
        args.push("gmsaas");

        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
        procInfo.executable = pipFile;
        procInfo.arguments = args;

        var newProc:NativeProcess = new NativeProcess();
        newProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, uninstallOutputDataHandler);
        newProc.addEventListener(NativeProcessExitEvent.EXIT, uninstallExit);
        newProc.start(procInfo);
    }

    private function uninstallExit(event:NativeProcessExitEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        process.removeEventListener(NativeProcessExitEvent.EXIT, uninstallExit)

        dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_UNINSTALL_COMPLETED))
    }

    private function uninstallOutputDataHandler(event:ProgressEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        var outputData:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)

        if (outputData.indexOf("Proceed (y/n)?") > -1) {
            process.standardInput.writeUTFBytes("y\r\n")
        }
    }
}
}
