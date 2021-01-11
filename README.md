# AtsMobileStation
AtsMobileStation is an application that manages the installation and startup of mobile drivers used by ATS test framework.  
AtsMobileStation is available on Windows (Android testing) and macOS systems (Android and iOS testing).

## Installation on Windows

### Requirements
- C++ Redistributable Packages for Visual Studio 2013 32 bits (https://www.microsoft.com/fr-FR/download/details.aspx?id=40784)

## Installation on macOS

**Before unzipping and using AtsMobileStation on macOS, complete the following steps:**

1. Install openssl
- If Brew utility not already installed, open Terminal.app and type:  
  `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"`
- Then run command:  
  `brew install openssl@1.1`

2. Bypass Apple Gatekeeper
- Download AtsMobileStation zip file.
- Before unzipping file, open Terminal.app and type:  
  `xattr -r -d com.apple.quarantine /path/of/your/zip/file`
- Unzip the file and open it. If macOS popup asking for permission to open AtsMobileStation appears, delete the unzipped file and repeat the previous step.

## Android testing

### Requirements
- macOS Catalina or Windows
- AtsMobileStation

### Devices configuration
- Disable device pin code 
- Enable **developer mode** and authorize the connection to the linked computer

**For Mi or Xiaomi Device :**

- Go to Settings
- Additional Settings
- Developer options
- Install via USB: Toggle On

## iOS testing 

### Requirements
- macOS Catalina 
- Xcode (download it on App Store)
- AtsMobileStation for macOS
- An Apple Developer account, and a developer license to test on physical devices 

### Setup provisionning profile into Xcode
- Open Xcode and go to 'Preferences' (Click on Xcode code in the left top corner)
- In 'Accounts', add a new account using '+' button in the bottom left corner
- Select 'Apple ID' in the dropdown list and enter your Apple Developer credentials in the next window
- When you're logged, click on "Manage Certificates". If there is no certificate associated with your workstation (no one is enlightened), click on "+" button -> "Apple Development" and "Done"

### AtsMobileStation configuration
- Open AtsMobileStation
- In the 'Connected devices' section, click on Apple logo
- In the textbox, put your Development team ID

### Devices configuration
- Disable device pin code 
- Enable Wi-Fi

### Error handling
- If the Apple keychain access ask credential recurrently: 
  - unplug the device
  - open the keychain access application
  - right click on "session"
  - "**lock** the keychain 'session'"
  - right click on "session"
  - "**unlock** the keychain 'session'"
  - enter your Mac credentials
  - plug your device again