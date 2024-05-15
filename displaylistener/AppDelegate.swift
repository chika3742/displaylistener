//
//  AppDelegate.swift
//  displaylistener
//
//  Created by 近松 和矢 on 2024/05/15.
//

import Foundation
import AppKit
import SwiftUI
import CoreAudio

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var previousExternalDisplayExists: Bool?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Display Detection")
        }
        
        statusItem?.menu = {
            let menu = NSMenu(title: "Display Listener")
            menu.addItem(.sectionHeader(title: "Listening Display"))
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
            
            return menu
        }()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDisplayParamChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        
        // run on startup
        let externalDisplayExists = getIsExternalDisplayOnline()
        handleExternalDisplayStateChange(isConnected: externalDisplayExists)
    }
    
    @objc
    func quit() {
        NSRunningApplication.current.terminate()
    }
    
    @objc
    func handleDisplayParamChange(notification: Notification) {
        let externalDisplayExists = getIsExternalDisplayOnline()
        
        if (previousExternalDisplayExists == nil || externalDisplayExists != previousExternalDisplayExists) {
            handleExternalDisplayStateChange(isConnected: externalDisplayExists)
        }
        
        previousExternalDisplayExists = externalDisplayExists
    }
    
    func handleExternalDisplayStateChange(isConnected: Bool) {
        setDefaultAudioOutputDevice(to: isConnected ? .proxy : .builtIn)
    }
    
    func getIsExternalDisplayOnline() -> Bool {
        var displayCount: UInt32 = 0
        let maxDisplays: UInt32 = 16
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        CGGetActiveDisplayList(maxDisplays, &displays, &displayCount)
        
        var externalDisplayExists = false
        
        for i in 0..<Int(displayCount) {
            let displayID = displays[i]
            let isBuiltIn = CGDisplayIsBuiltin(displayID)
            if (isBuiltIn == 0) {
                externalDisplayExists = true
            }
        }
        
        return externalDisplayExists
    }
    
    func setDefaultAudioOutputDevice(to: OutputDeviceType) {
        let audioDevices = getAudioOutputDevices()
        
        for device in audioDevices {
            if (to == .builtIn && device.isBuiltIn || to == .proxy && device.name == "Proxy Audio Device") {
                if (device.id == getCurrentDefaultAudioDeviceID()) {
                    break
                }
                
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var deviceId = device.id
                
                let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceId)
                
                if (status == noErr) {
                    print("Audio device set to \(device.name).")
                } else {
                    print("Failed to set audio device to \(device.name)")
                }
            }
        }
    }
    
    func getCurrentDefaultAudioDeviceID() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceId: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceId)
        
        return deviceId
    }
    
    func getAudioOutputDevices() -> [AudioDevice] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices)
        
        var outputDevices: [AudioDevice] = []
        for device in devices {
            var isOutput: UInt32 = 0
            var isOutputSize = UInt32(MemoryLayout<UInt32>.size)
            address.mSelector = kAudioDevicePropertyStreams
            address.mScope = kAudioDevicePropertyScopeOutput
            AudioObjectGetPropertyData(device, &address, 0, nil, &isOutputSize, &isOutput)
            
            if (isOutput > 0) {
                // get device name
                var deviceName = "" as CFString
                var nameSize = UInt32(MemoryLayout<CFString>.size)
                address.mSelector = kAudioObjectPropertyName
                _ = withUnsafeMutablePointer(to: &deviceName) { pointer in
                    AudioObjectGetPropertyData(device, &address, 0, nil, &nameSize, pointer)
                }
                
                // get transport type (is/isn't built-in)
                var transportType: UInt32 = 0
                var transportTypeSize = UInt32(MemoryLayout<UInt32>.size)
                address.mSelector = kAudioDevicePropertyTransportType
                AudioObjectGetPropertyData(device, &address, 0, nil, &transportTypeSize, &transportType)
                
                outputDevices.append(AudioDevice(id: device, name: deviceName as String, isBuiltIn: transportType == kAudioDeviceTransportTypeBuiltIn))
            }
        }
        
        return outputDevices
    }
}

enum OutputDeviceType {
    case builtIn
    case proxy
}

class AudioDevice {
    let id: AudioDeviceID
    let name: String
    let isBuiltIn: Bool
    
    init(id: AudioDeviceID, name: String, isBuiltIn: Bool) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
    }
}
