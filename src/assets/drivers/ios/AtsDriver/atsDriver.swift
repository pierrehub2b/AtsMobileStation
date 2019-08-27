//
//  atsDriver.swift
//  atsDriver
//
//  Copyright © 2019 atsDriver. All rights reserved.
//

import Foundation
import UIKit
import XCTest
import Embassy
import EnvoyAmbassador

struct UIElement: Codable {
    let id: String
    let tag: String
    let clickable: Bool
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    var children: [UIElement]?
    var attributes: [String:String]
    let channelY: Double?
    let channelHeight: Double?
}

enum actionsEnum: String {
    case DRIVER = "driver"
    case APP = "app"
    case START = "start"
    case STOP = "stop"
    case SWITCH = "switch"
    case CAPTURE = "capture"
    case ELEMENT = "element"
    case TAP = "tap"
    case INPUT = "input"
    case SWIPE = "swipe"
    case BUTTON = "button"
    case INFO = "info"
    case QUIT = "quit"
    case EMPTY = "&empty;"
}

enum deviceButtons: String {
    case HOME = "home"
    case SOUNDUP = "soundup"
    case SOUNDDOWN = "sounddown"
    case SILENTSWITCH = "silentswitch"
    case LOCK = "lock"
    case ENTER = "enter"
    case RETURN = "return"
    case ORIENTATION = "orientation"
}

struct Frame {
    let label: String
    let identifier: String
    let placeHolderValue: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

class atsDriver: XCTestCase {
    
    var port = 8080
    var app: XCUIApplication!
    var portUdp: Int = 47633
    var udpServer: UDPServer!
    var currentAppIdentifier: String = ""
    var allElements: UIElement? = nil
    var resultElement: [String: Any] = [:]
    var captureStruct: String = ""
    var flatStruct: [String: Frame] = [:]
    var thread: Thread! = nil
    
    let osVersion = UIDevice.current.systemVersion
    let model = UIDevice.current.name
    let uid = UIDevice.current.identifierForVendor!.uuidString
    let deviceWidth = UIScreen.main.bounds.width
    let deviceHeight = UIScreen.main.bounds.height

    var continueExecution = true
    
    var applicationControls =
        [
         "any","other","application","group","window","sheet","drawer","alert","dialog","button","radioButton","radioGroup","checkbox","disclosureTriangle","popUpButton","comboBox","menuButton","toolbarButton","popOver",
         "keyboard","key","navigationBar","tabBar","tabGroup","toolBar","statusBar","table","tableRow","tableColumn","outline","outlineRow","browser","collectionView","slider","pageIndicator","progressIndicator",
         "activityIndicator","segmentedControl","picker","pickerWheel","switch","toogle","link","image","icon","searchField","scrollView","scrollBar","staticText","textField","secureTextField","datePicker","textView",
         "menu","menuItem","menuBar","menuBarItem","map","webView","incrementArrow","decrementArrow","timeline","ratingIndicator","valueIndicator","splitGroup","splitter","relevanceIndicator","colorWell","helpTag","matte",
         "dockItem","ruler","rulerMarker","grid","levelIndicator","cell","layoutArea","layoutItem","handle","stepper","tab","touchBar","statusItem"
        ]
    
    //var udpThread: Thread!

    override func setUp() {
        super.setUp()
        
        
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        
        self.thread = Thread(target: self, selector: Selector(("udpStart")), object: nil)
        setupWebApp()
        setupApp()
        

    }
    
    func udpStart(){
        self.udpServer = UDPServer(port: self.portUdp)
        print("Swift Echo Server Sample")
        print("Connect with a command line window by entering 'telnet ::1 \(portUdp)'")
        
        self.udpServer.run()
    }
    
    func getEnumStringValue(rawValue: UInt) -> String {
        switch rawValue {
        case 0:
            return "any"
        case 1:
            return "other"
        case 2:
            return "application"
        case 3:
            return "group"
        case 4:
            return "window"
        case 5:
            return "sheet"
        case 6:
            return "drawer"
        case 7:
            return "alert"
        case 8:
            return "dialog"
        case 9:
            return "button"
        case 10:
            return "radioButton"
        case 11:
            return "radioGrouo"
        case 12:
            return "checkBox"
        case 13:
            return "disclosureTriangle"
        case 14:
            return "popUpButton"
        case 15:
            return "comboBox"
        case 16:
            return "menuButton"
        case 17:
            return "toolbarButton"
        case 18:
            return "popOver"
        case 19:
            return "keyboard"
        case 20:
            return "key"
        case 21:
            return "navigationBar"
        case 22:
            return "tabBar"
        case 23:
            return "tabGroup"
        case 24:
            return "toolBar"
        case 25:
            return "statusBar"
        case 26:
            return "table"
        case 27:
            return "tableRow"
        case 28:
            return "tableColumn"
        case 29:
            return "outline"
        case 30:
            return "outlineRow"
        case 31:
            return "browser"
        case 32:
            return "collectionView"
        case 33:
            return "slider"
        case 34:
            return "pageIndicator"
        case 35:
            return "progressIndicator"
        case 36:
            return "activityIndicator"
        case 37:
            return "segmentedControl"
        case 38:
            return "picker"
        case 39:
            return "pickerWheel"
        case 40:
            return "switch"
        case 41:
            return "toggle"
        case 42:
            return "link"
        case 43:
            return "image"
        case 44:
            return "icon"
        case 45:
            return "searchField"
        case 46:
            return "scrollView"
        case 47:
            return "scrollBar"
        case 48:
            return "staticText"
        case 49:
            return "textField"
        case 50:
            return "secureTextField"
        case 51:
            return "datePicker"
        case 52:
            return "textView"
        case 53:
            return "menu"
        case 54:
            return "menuItem"
        case 55:
            return "menuBar"
        case 56:
            return "menuBarItem"
        case 57:
            return "map"
        case 58:
            return "webView"
        case 59:
            return "incrementArrow"
        case 60:
            return "decrementArrow"
        case 61:
            return "timeline"
        case 62:
            return "ratingIndicator"
        case 63:
            return "valueIndicator"
        case 64:
            return "splitGroup"
        case 65:
            return "splitter"
        case 66:
            return "relevanceIndicator"
        case 67:
            return "colorWell"
        case 68:
            return "helpTag"
        case 69:
            return "matte"
        case 70:
            return "dockItem"
        case 71:
            return "ruler"
        case 72:
            return "rulerMarker"
        case 73:
            return "grid"
        case 74:
            return "levelIndicator"
        case 75:
            return "cell"
        case 76:
            return "layoutArea"
        case 77:
            return "layoutItem"
        case 78:
            return "handle"
        case 79:
            return "stepper"
        case 80:
            return "tab"
        case 81:
            return "touchBar"
        case 82:
            return "statusItem"
        default:
            return "any"
        }
    }
    
    // setup the Embassy web server for testing
    private func setupWebApp() {
        
        let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
        
        for i in 8080..<65000 {
            let (isFree, _) = checkTcpPortForListen(port: UInt16(i))
            if isFree == true {
                self.port = i
                break;
            }
        }
        
        let server = DefaultHTTPServer(eventLoop: loop, interface: "0.0.0.0", port: self.port) {
            (
            environ: [String: Any],
            startResponse: ((String, [(String, String)]) -> Void),
            sendBody: ((Data) -> Void)
            ) in
            // Start HTTP response
            startResponse("200 OK", [("Content-Type", "application/json")])
            let query_String = environ["PATH_INFO"]! as! String
            let action = query_String.replacingOccurrences(of: "/", with: "")
            var parameters: [String] = [String]()
            
            let input = environ["swsgi.input"] as! SWSGIInput
            input { data in
                // handle the whole data here
                if let textData = String(bytes: data, encoding: .utf8) {
                    let tableData = textData.split(separator: "\n")
                    if tableData.count > 0 {
                        for index in 0...tableData.count-1 {
                            parameters.append(String(tableData[index]))
                        }
                    }
                }
            }
            self.resultElement = [:]
            if(action == "") {
                self.resultElement["status"] = -11
                self.resultElement["message"] = "unknow command"
            } else {
                switch action {
                    case actionsEnum.DRIVER.rawValue:
                        if(parameters.count > 0) {
                            if(actionsEnum.START.rawValue == parameters[0]) {
                                XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
                                XCUIDevice.shared.press(.home)
                                
                                self.driverInfoBase()
                                self.resultElement["status"] = 0
                                self.resultElement["screenCapturePort"] = 47633
                                self.thread.start()
                                
                            } else {
                                if(actionsEnum.STOP.rawValue == parameters[0]) {
                                    if(self.app != nil){
                                        self.app.terminate()
                                        self.resultElement["status"] = 0
                                        self.resultElement["message"] = "stop ats driver"
                                    }
                                    XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
                                } else {
                                    if(actionsEnum.QUIT.rawValue == parameters[0]) {
                                        self.tearDown()
                                        self.thread.cancel()
                                        self.resultElement["status"] = 0
                                        self.resultElement["message"] = "close ats driver"
                                    } else if(actionsEnum.INFO.rawValue == parameters[0]) {
                                        self.resultElement["status"] = 0
                                        self.resultElement["message"] = "get info"
                                    } else {
                                        self.resultElement["message"] = "missiing driver action type " + parameters[0]
                                        self.resultElement["status"] = -42
                                    }
                                }
                            }
                        } else {
                            self.resultElement["message"] = "missing driver action"
                            self.resultElement["status"] = -41
                        }
                        break
                    case actionsEnum.BUTTON.rawValue:
                        if(parameters.count > 0) {
                            if(deviceButtons.HOME.rawValue == parameters[0]) {
                                XCUIDevice.shared.press(.home)
                                self.resultElement["status"] = 0
                                self.resultElement["message"] = "press home button"
                            } else {
                                if(deviceButtons.ORIENTATION.rawValue == parameters[0]) {
                                    if(XCUIDevice.shared.orientation == .landscapeLeft) {
                                        XCUIDevice.shared.orientation = .portrait
                                        self.resultElement["status"] = 0
                                        self.resultElement["message"] = "orientation to portrait mode"
                                    } else {
                                        XCUIDevice.shared.orientation = .landscapeLeft
                                        self.resultElement["status"] = 0
                                        self.resultElement["message"] = "orientation to landscape mode"
                                    }
                                } else {
                                    self.resultElement["message"] = "unknow button " + parameters[0]
                                    self.resultElement["status"] = -42
                                }
                            }
                            
                        } else {
                            self.resultElement["message"] = "missing button action"
                            self.resultElement["status"] = -41
                        }
                        break
                    case actionsEnum.CAPTURE.rawValue:
                        self.allElements = nil
                        self.flatStruct = [:]
                        if(self.app == nil) {
                            self.resultElement["message"] = "no app has been launched"
                            self.resultElement["status"] = -99
                            break
                        }
                        
                        let description = self.app.debugDescription
                        var descriptionTable = description.split(separator: "\n")
                        var leveledTable: [(Int,String)] = [(Int,String)]()
                        for index in 3...descriptionTable.count-8 {
                            //no traitment of line that are not reference composants
                            var currentLine = String(descriptionTable[index])
                            var blankSpacesAtStart = 0
                            for char in currentLine.characters.indices {
                                if(currentLine[char] == " ") {
                                    blankSpacesAtStart += 1
                                } else {
                                    break
                                }
                            }
                            let level = (blankSpacesAtStart / 2) - 1
                            leveledTable.append((level, currentLine))
                        }
                        
                        var rootLine = leveledTable[0].1.split(separator: ",")
                        let levelUID = UUID().uuidString
                        
                        let rootNode = UIElement(
                            id: levelUID,
                            tag: "root",
                            clickable: false,
                            x: Double(self.cleanString(input: String(rootLine[2]))) as! Double,
                            y: Double(self.cleanString(input: String(rootLine[3]))) as! Double,
                            width: Double(self.cleanString(input: String(rootLine[4]))) as! Double,
                            height: Double(self.cleanString(input: String(rootLine[5]))) as! Double,
                            children: self.getChildrens(currentLevel: 1, currentIndex: 0, endedIndex: leveledTable.count-1, leveledTable: leveledTable),
                            attributes: [:],
                            channelY: 0,
                            channelHeight: Double(self.cleanString(input: String(rootLine[5])))
                        )

                        self.captureStruct = self.convertIntoJSONString(arrayObject: rootNode)
                        break
                    case actionsEnum.ELEMENT.rawValue:
                        if(parameters.count > 1) {
                            let flatElement = self.flatStruct[parameters[0]]
                            var element: XCUIElement? = nil
                            if(flatElement?.label != "") {
                                element = self.retrieveElement(parameter: "label", field: flatElement!.label)
                            } else if(flatElement?.identifier != "") {
                                element = self.retrieveElement(parameter: "identifier", field: flatElement!.identifier)
                            } else {
                                element = self.retrieveElement(parameter: "placeholderValue", field: flatElement!.placeHolderValue)
                            }
                            if(element != nil && !element!.isHittable) {
                                element = nil
                                self.resultElement["status"] = -22
                                self.resultElement["message"] = "element not in the screen"
                            }
                            if(element != nil) {
                                if(actionsEnum.INPUT.rawValue == parameters[1]) {
                                    let text = parameters[2]
                                    if(element!.elementType.rawValue == 49 || element!.elementType.rawValue == 50 || element!.elementType.rawValue == 45) {
                                        element?.tap()
                                        if(text == actionsEnum.EMPTY.rawValue) {
                                            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: (element?.value as? String)?.count ?? 0)
                                            element?.typeText(deleteString)
                                            self.resultElement["status"] = 0
                                            self.resultElement["message"] = "element clear text"
                                        } else {
                                            element?.typeText(text)
                                            self.resultElement["status"] = 0
                                            self.resultElement["message"] = "element tap text: " + text
                                        }
                                    } else {
                                        element?.tap()
                                        self.resultElement["status"] = 0
                                        self.resultElement["message"] = "not a text input, just tap"
                                    }
                                } else {
                                    var offSetX = 0
                                    var offSetY = 0
                                    if(parameters.count > 3) {
                                        offSetX = Int(parameters[2])!
                                        offSetY = Int(parameters[3])!
                                    }
                                    
                                    let calculateX = Double(element?.frame.minX ?? 0) + Double(offSetX)
                                    let calculateY = Double(element?.frame.minY ?? 0) + Double(offSetY)
                                    
                                    if(actionsEnum.TAP.rawValue == parameters[1]) {
                                        self.tapCoordinate(at: calculateX, and: calculateY)
                                        self.resultElement["status"] = 0
                                        self.resultElement["message"] = "tap on element"
                                    } else {
                                        if(actionsEnum.SWIPE.rawValue == parameters[1]) {
                                            let directionX = Double(parameters[4]) ?? 0.0
                                            let directionY = Double(parameters[5]) ?? 0.0
                                            if(directionX > 0.0) {
                                                element?.swipeRight()
                                            }
                                            if(directionX < 0.0) {
                                                element?.swipeLeft()
                                            }
                                            if(directionY > 0.0) {
                                                element?.swipeUp()
                                            }
                                            if(directionY < 0.0) {
                                                element?.swipeDown()
                                            }
                                            self.resultElement["status"] = 0
                                            self.resultElement["message"] = "swipe element"
                                        }
                                    }
                                }
                            } else {
                                self.resultElement["status"] = -21
                                self.resultElement["message"] = "missing element"
                            }
                        }  else {
                            self.resultElement["message"] = "missing element action"
                            self.resultElement["status"] = -41
                        }
                        break
                    case actionsEnum.APP.rawValue:
                        if(parameters.count > 1) {
                            if(actionsEnum.START.rawValue == parameters[0]) {
                                self.app = XCUIApplication(bundleIdentifier: parameters[1])
                                self.app.launch();
                                self.resultElement["message"] = "start app " + parameters[1]
                                self.resultElement["status"] = 0
                                self.resultElement["label"] = self.app.label
                                self.resultElement["icon"] = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAACXBIWXMAAC4jAAAuIwF4pT92AAAAB3RJTUUH4wgNCzQS2tg9zgAAABl0RVh0Q29tbWVudABDcmVhdGVkIHdpdGggR0lNUFeBDhcAAAAMSURBVAjXY2DY/QYAAmYBqC0q4zEAAAAASUVORK5CYII="
                                self.resultElement["version"] = "0.0.0"
                            } else {
                                if(actionsEnum.SWITCH.rawValue == parameters[0]) {
                                    self.app = XCUIApplication(bundleIdentifier: parameters[1])
                                    self.app.activate()
                                    self.resultElement["message"] = "switch app " + parameters[1]
                                    self.resultElement["status"] = 0
                                } else {
                                    if(actionsEnum.STOP.rawValue == parameters[0]) {
                                        self.app = XCUIApplication(bundleIdentifier: parameters[1])
                                        self.app.terminate()
                                        self.resultElement["message"] = "stop app " + parameters[1]
                                        self.resultElement["status"] = 0
                                    } else {
                                        self.resultElement["message"] = "missiing app action type " + parameters[0]
                                        self.resultElement["status"] = -42
                                    }
                                }
                                
                            }
                            
                        } else {
                            self.resultElement["message"] = "missing app action"
                            self.resultElement["status"] = -41
                        }
                        break
                    case actionsEnum.INFO.rawValue:
                        self.driverInfoBase()
                        self.resultElement["message"] = "device capabilities"
                        self.resultElement["status"] = 0
                        self.resultElement["id"] = self.uid
                        self.resultElement["model"] = self.model
                        self.resultElement["manufacturer"] = "Apple"
                        self.resultElement["brand"] = "Apple"
                        self.resultElement["version"] = self.osVersion
                        self.resultElement["bluetoothName"] = ""
                        break
                    default:
                        self.resultElement["status"] = -12
                        self.resultElement["message"] = "unknow command " + action
                        break
                    }
            }
            
            if(action == actionsEnum.CAPTURE.rawValue) {
                sendBody(Data(self.captureStruct.utf8))
            } else {
                if let theJSONData = try?  JSONSerialization.data(
                    withJSONObject: self.resultElement,
                    options: []
                    ),
                    let theJSONText = String(data: theJSONData,
                                             encoding: String.Encoding.utf8) {
                    sendBody(Data(theJSONText.utf8))
                }
            }
            sendBody(Data())
        }
        
        // Start HTTP server to listen on the port
        try! server.start()
        
        let endPoint = getWiFiAddress()! + ":" + String(self.port)
        fputs("ATSDRIVER_DRIVER_HOST=" + endPoint + "\n", stderr)
        
        // Run event loop
        loop.runForever()
    }
    
    func matchingStrings(input: String, regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = input as NSString
        let results  = regex.matches(in: input, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
    
    func split(input: String, regex: String) -> [String] {
        
        guard let re = try? NSRegularExpression(pattern: regex, options: [])
            else { return [] }
        
        let nsString = input as NSString // needed for range compatibility
        let stop = "<SomeStringThatYouDoNotExpectToOccurInSelf>"
        let modifiedString = re.stringByReplacingMatches(
            in: input,
            options: [],
            range: NSRange(location: 0, length: nsString.length),
            withTemplate: "")
        return modifiedString.components(separatedBy: stop)
    }
    
    func getChildrens(currentLevel: Int, currentIndex: Int, endedIndex: Int, leveledTable: [(Int,String)]) -> [UIElement] {
        var tableToReturn: [UIElement] = [UIElement]()
        for line in currentIndex...leveledTable.count-1 {
            let levelUID = UUID().uuidString
            let currentLine = leveledTable[line]
            var splittedLine: [String] = [String]()
            
            var currentString = ""
            var stopSplitting = false
            var index = 0
            var isValue = false
            for char in currentLine.1 {
                if(isValue) {
                    currentString += String(char)
                    if((index + 1) == currentLine.1.count) {
                        splittedLine.append(currentString)
                    }
                } else if(currentString.contains("value")) {
                    isValue = !isValue
                    currentString += String(char)
                } else if(char == "," && !stopSplitting){
                    splittedLine.append(currentString)
                    currentString = ""
                } else {
                    if(char == "'") {
                        stopSplitting = !stopSplitting
                    }
                    currentString += String(char)
                    if((index + 1) == currentLine.1.count) {
                        splittedLine.append(currentString)
                    }
                }
                index += 1
            }
            
            if(currentLine.0 == currentLevel && endedIndex >= line) {
                var endIn = line + 1
                for el in endIn...leveledTable.count-1 {
                    if(leveledTable[el].0 >= currentLevel+1) {
                        endIn += 1
                    } else {
                        break
                    }
                }
                
                var attr: [String: String] = [String: String]()
                
                var label = ""
                var placeHolder = ""
                var identifier = ""
                var value = ""
                let pattern = "'(.*?)'"
                for str in splittedLine {
                    if(str.contains("identifier")) {
                        identifier = (self.matchingStrings(input: String(str), regex: pattern).first?[1])!
                    }
                    if(str.contains("label")) {
                        label = (self.matchingStrings(input: String(str), regex: pattern).first?[1])!
                    }
                    if(str.contains("placeholderValue")) {
                        placeHolder = (self.matchingStrings(input: String(str), regex: pattern).first?[1])!
                    }
                    if(str.contains("value")) {
                        var valueTable = str.split(separator: ":")
                        if(valueTable.count == 2) {
                            let val = valueTable[1]
                            value = val.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
                
                var enabled = true
                if(currentLine.1.contains("Disabled")) {
                    enabled = false
                }
                
                var selected = false
                if(currentLine.1.contains("Selected")) {
                    selected = true
                }
                
                
                attr["text"] = label
                attr["description"] = placeHolder
                attr["checkable"] = String(self.cleanString(input: String(splittedLine[0])) == "checkbox")
                attr["enabled"] = String(enabled)
                attr["identifier"] = identifier
                attr["selected"] = String(selected)
                attr["editable"] = String(enabled)
                attr["numeric"] = "false"
                attr["value"] = value
                
                let x = Double(self.cleanString(input: String(splittedLine[2]))) as! Double
                let y = Double(self.cleanString(input: String(splittedLine[3]))) as! Double
                let width = Double(self.cleanString(input: String(splittedLine[4]))) as! Double
                let height = Double(self.cleanString(input: String(splittedLine[5]))) as! Double
            
                tableToReturn.append(UIElement(
                    id: levelUID,
                    tag: self.cleanString(input: String(splittedLine[0])),
                    clickable: true,
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    children: self.getChildrens(currentLevel: currentLevel+1, currentIndex: line+1, endedIndex: endIn, leveledTable: leveledTable),
                    attributes: attr,
                    channelY: nil,
                    channelHeight: nil
                ))
                
                flatStruct[levelUID] = Frame(label: label, identifier: identifier, placeHolderValue: placeHolder, x: x, y: y, width: width, height: height)
            }
        }
        return tableToReturn
    }
    
    func cleanString(input: String) -> String {
        var output = input.replacingOccurrences(of: "{", with: "")
        output = output.replacingOccurrences(of: "}", with: "")
        return output.replacingOccurrences(of: " ", with: "")
    }
    
    func tapCoordinate(at xCoordinate: Double, and yCoordinate: Double) {
        let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let coordinate = normalized.withOffset(CGVector(dx: xCoordinate, dy: yCoordinate))
        
        coordinate.tap()
    }
    
    func retrieveElement(parameter: String, field: String) -> XCUIElement? {
        var fieldValue = field.replacingOccurrences(of: "%27", with: "'")
        fieldValue = fieldValue.replacingOccurrences(of: "%22", with: "'")
        fieldValue = fieldValue.replacingOccurrences(of: "%20", with: " ")
        let predicate = NSPredicate(format: "\(parameter) == '\(fieldValue)'")
        if(self.app == nil) {
            return nil
        }
        let elem = self.app.descendants(matching: .any).element(matching: predicate)
        if(elem.exists) {
            return elem.firstMatch
        } else {
            return nil
        }
    }
    
    func convertIntoJSONString(arrayObject: UIElement) -> String {
        do {
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(arrayObject)
            let json = String(data: jsonData, encoding: String.Encoding.utf8) ?? "no values"
            return json
        } catch let error as NSError {
            print("Array convertIntoJSON - \(error.description)")
        }
        return ""
    }
    
    func stringify(json: Any, prettyPrinted: Bool = false) -> String {
        var options: JSONSerialization.WritingOptions = []
        if prettyPrinted {
            options = JSONSerialization.WritingOptions.prettyPrinted
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: options)
            if let string = String(data: data, encoding: String.Encoding.utf8) {
                return string
            }
        } catch {
            print(error)
        }
        
        return ""
    }
    
    func getQueryStringParameter(query_string: String, param: String) -> String {
        let params = query_string.components(separatedBy: "&")
        for item in params {
            var currentParam = item.components(separatedBy: "=")
            if(currentParam.count != 2) { return "" }
            if(currentParam[0] == param) {
                return currentParam[1]
            }
        }
        return ""
    }
    
    // set up XCUIApplication
    private func setupApp() {
        app = XCUIApplication()
        app.launchEnvironment["RESET_LOGIN"] = "1"
        app.launchEnvironment["ENVOY_BASEURL"] = "http://localhost:\(self.port)"
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func driverInfoBase() {
        self.resultElement["os"] = "ios"
        self.resultElement["driverVersion"] = "1.0.0"
        self.resultElement["systemName"] = model + " " + osVersion
        self.resultElement["deviceWidth"] = deviceWidth
        self.resultElement["deviceHeight"] = deviceHeight
        self.resultElement["channelWidth"] = deviceWidth
        self.resultElement["channelHeight"] = deviceHeight
        self.resultElement["channelX"] = 0
        self.resultElement["channelY"] = 0
    }
    
    func testExecuteCommand() {
        while continueExecution {
            
        }
    }
    
    func checkTcpPortForListen(port: in_port_t) -> (Bool, descr: String) {
        
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 {
            return (false, "SocketCreationFailed, \(descriptionOfLastError())")
        }
        
        var addr = sockaddr_in()
        let sizeOfSockkAddr = MemoryLayout<sockaddr_in>.size
        addr.sin_len = __uint8_t(sizeOfSockkAddr)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeOfSockkAddr))
        
        if Darwin.bind(socketFileDescriptor, &bind_addr, socklen_t(sizeOfSockkAddr)) == -1 {
            let details = descriptionOfLastError()
            release(socket: socketFileDescriptor)
            return (false, "\(port), BindFailed, \(details)")
        }
        if listen(socketFileDescriptor, SOMAXCONN ) == -1 {
            let details = descriptionOfLastError()
            release(socket: socketFileDescriptor)
            return (false, "\(port), ListenFailed, \(details)")
        }
        release(socket: socketFileDescriptor)
        return (true, "\(port) is free for use")
    }
    
    func release(socket: Int32) {
        Darwin.shutdown(socket, SHUT_RDWR)
        close(socket)
    }
    
    func descriptionOfLastError() -> String {
        return String.init(cString: (UnsafePointer(strerror(errno))))
    }
    
    func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 only
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                } else if name == "en1" {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(1), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
}
