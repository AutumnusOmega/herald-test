//
//  AppDelegate.swift
//  HeraldTest
//
//  Created by Andres Colubri on 8/25/21.
//

import UIKit
import Herald

@main
class AppDelegate: UIResponder, UIApplicationDelegate, SensorDelegate {
    var window : UIWindow?
    
    public static var instance: AppDelegate?
    
    var payloadDataSupplier: IllnessDataPayloadSupplier?
    var sensor: SensorArray?
    
    var currentPeers: [Int: PeerInfo] = [:]
    
    let RSSI_THRESHOLD = -30.0
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.instance = self
    
        startPhone()
        
        return true
    }

    // MARK: UISceneSession Lifecycle
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {

        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {

    }
    
    private var uniqueID: String = ""
    static let PREF_UNIQUE_ID: String = "PREF_UNIQUE_DEVICE_ID"
    private func getUniqueId() -> String {
        if uniqueID == "" {
            uniqueID = UserDefaults.standard.string(forKey: AppDelegate.PREF_UNIQUE_ID) ?? ""
            if uniqueID == "" {
                uniqueID = UUID().uuidString
                UserDefaults.standard.set(uniqueID, forKey: AppDelegate.PREF_UNIQUE_ID)
            }
        }
        return uniqueID
    }
    
    private func hashCode(_ text: String) -> Int {
        var hash = UInt64 (5381)
        let buf = [UInt8](text.utf8)
        for b in buf {
            hash = 127 * (hash & 0x00ffffffffffffff) + UInt64(b)
        }
        let value = Int(hash.remainderReportingOverflow(dividingBy: UInt64(Int32.max)).partialValue)
        return value
    }
    
    private func identifier() -> Int {
//           let text = UIDevice.current.name + ":" + UIDevice.current.model + ":" + UIDevice.current.systemName + ":" + UIDevice.current.systemVersion
//           var hash = UInt64 (5381)
//           let buf = [UInt8](text.utf8)
//           for b in buf {
//               hash = 127 * (hash & 0x00ffffffffffffff) + UInt64(b)
//           }
//           let value = Int32(hash.remainderReportingOverflow(dividingBy: UInt64(Int32.max)).partialValue)
         let v = getUniqueId()
         let h = hashCode(v)
         return h
     }

    func startPhone() {
        payloadDataSupplier = IllnessDataPayloadSupplier(identifier: identifier())
        BLESensorConfiguration.payloadDataUpdateTimeInterval = TimeInterval.minute
        BLESensorConfiguration.logLevel = .debug
        sensor = SensorArray(payloadDataSupplier!)
        sensor?.add(delegate: self)
        sensor?.start()
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        print(sensor.rawValue + ",didDetect=" + didDetect.description)
    }
    
    // TODO: Get Message
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        print(sensor.rawValue + ",didRead=" + didRead.shortName + ",fromTarget=" + fromTarget.description)
        parsePayload("didRead", sensor, didRead, nil, fromTarget)
    }
    
    // Get Message
    func sensor(_ sensor: SensorType, didReceive: Data, fromTarget: TargetIdentifier) {
        print(sensor.rawValue + ",didReceive=" + didReceive.base64EncodedString() + ",fromTarget=" + fromTarget.description)
    }
    
    // TODO: Gets us proximity
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        print(sensor.rawValue + ",didMeasure=" + didMeasure.description + ",fromTarget=" + fromTarget.description)
    }
    
    func sensor(_ sensor: SensorType, didVisit: Location?) {
        print(sensor.rawValue + ",didVisit=" + String(describing: didVisit))
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {
        print(sensor.rawValue + ",didMeasure=" + didMeasure.description + ",fromTarget=" + fromTarget.description + ",withPayload=" + withPayload.shortName)
        
        parsePayload("didMeasure", sensor, withPayload, didMeasure, fromTarget)
    }
    
    func sensor(_ sensor: SensorType, didUpdateState: SensorState) {
        print(sensor.rawValue + ",didUpdateState=" + didUpdateState.rawValue)
    }
    
    func parsePayload(_ source: String, _ sensor: SensorType, _ payloadData: PayloadData, _ proximity: Proximity?, _ fromTarget: TargetIdentifier) {
        
        let identifer = IllnessDataPayloadSupplier.getIdentifierFromPayload(illnessPayload: payloadData)
        let status = IllnessDataPayloadSupplier.getIllnessStatusFromPayload(illnessPayload: payloadData)
    
        print("RECEIVED PAYLOAD IDENTIFIER: ", identifer)
        print("RECEIVED STATUS: ", status.toString())
        
        var info = currentPeers[identifer]
        
        if (info == nil) {
            info = PeerInfo()
            info!.status = status
            currentPeers[identifer] = info
        }
       
        if (proximity != nil) {
            info!.addRSSI(value: proximity!.value)
            print("RSSI value: ", proximity!.value)
        }
        
        
        if (RSSI_THRESHOLD < info!.getRSSI() && 10 < info!.data.count) {
            // not in contact anymore, remove
            currentPeers.removeValue(forKey: identifer)
        }
        
        let lastFiveMinutes = Date().timeIntervalSince(info!.lastSeen)
        let fiveMinutesFromNow: TimeInterval = 60 * 5
        
        if (lastFiveMinutes >= fiveMinutesFromNow) {
            currentPeers.removeValue(forKey: identifer)
        }
        
        EventHelper.triggerPeerDetect()
        
    }
}

