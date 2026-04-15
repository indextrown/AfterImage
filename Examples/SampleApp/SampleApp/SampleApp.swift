//
//  SampleApp.swift
//  SampleApp
//
//  Created by 김동현 on 4/15/26.
//

import AfterImage
import SwiftUI

@main
struct SampleApp: App {
    init() {
        AfterImage.shared.configure(SampleConfiguration.afterImageConfiguration)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
