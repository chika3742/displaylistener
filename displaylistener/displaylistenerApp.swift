//
//  displaylistenerApp.swift
//  displaylistener
//
//  Created by 近松 和矢 on 2024/05/15.
//

import SwiftUI

@main
struct displaylistenerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
