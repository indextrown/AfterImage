//
//  SimpleListApp.swift
//  SimpleListApp
//
//  Created by 김동현 on 4/15/26.
//

import AfterImage
import SwiftUI

@main
struct SimpleListApp: App {
    init() {
        let configuration = AfterImageConfiguration(
            memoryCacheConfiguration: MemoryCacheConfiguration(
                countLimit: 200,
                totalCostLimit: 40 * 1024 * 1024
            ),
            diskCacheConfiguration: DiskCacheConfiguration(
                directoryURL: FileManager.default.urls(
                    for: .cachesDirectory,
                    in: .userDomainMask
                )[0]
                .appendingPathComponent("SimpleListApp-AfterImage", isDirectory: true),
                defaultTTL: 3 * 24 * 60 * 60,
                countLimit: 500,
                totalSizeLimit: 100 * 1024 * 1024
            )
        )
        
        AfterImage.shared.configure(configuration)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
