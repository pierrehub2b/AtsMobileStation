# AtsMobileStation
PC and Mac OS application to start and install mobile drivers used by ATS test framework

# Before launching AtsMobileStation on MacOS, please do actions below
- If not already install, launch the command: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
- Launch the command: brew install openssl@1.1
**After the first launch, your system possibly tells you that the library "luajit" is not safe. For authorize it, go to your security settings and click on button "allow acess"**

## iOS Devices
**This procedure is useless if you're using iOS Simulators**
### Apple Developer settings
To execute automated tests on physical iPhone devices, you need to create an Apple developer account and subscribe to a developer licence

### Prerequisites 
- Have an Xcode downloaded and **installed**
- the device **must be in WIFI mode and unlock pin code disabled**

### 1/ Setup provisionning profile into Xcode
- Open Xcode and go to 'Preferences' (Click on Xcode code in the left top corner)
- In 'Accounts', add a new account using '+' button in the bottom left corner
- Select 'Apple ID' in the dropdown list and enter your Apple Developer credentials in the next window
- When you're logged, click on "Manage Certificates". If there is no certificate associated with your workstation (no one is enlightened), click on "+" button -> "Apple Development" and "Done"
- Save and quit xCode

### 2/ Set the Development team ID and retrieve the devices list
- Open AtsMobileStation and plug an iPhone device
- In the 'Connected devices' section, click on Apple logo
- In the textbox, put your Development team ID
- Click on 'Export device list' and save the output file on your disk

### 3/ Push informations to Apple Developer Website
- Go and login to your apple dev account (https://developer.apple.com)
- Go to 'Certificates, ID's and profiles' -> 'Devices' and add new devices by pushing '+' button
- In 'Register Multiple Devices', upload the file generated previously and save

### 4/ Test if driver working effectively
- Go to AtsMobileStation
- unplug and plug your iPhone device
- your driver should start (by seeing the green check image, and show you an Ip adress and port)

### 5/ Error handling
- If the Apple keychain access ask credential recurrently: 
  - unplug the device
  - open the keychain access application
  - right click on "session"
  - "**lock** the keychain 'session'"
  - right click on "session"
  - "**unlock** the keychain 'session'"
  - enter your Mac credentials
  - plug your device again

## Android devices
### Prerequisites
- the device **must be in WIFI and don't have a pin code** 
- Enable the **developer mode** and authorize the connection to the linked computer

**You can now go the ATS Framework and begin to use it with your physical device.**