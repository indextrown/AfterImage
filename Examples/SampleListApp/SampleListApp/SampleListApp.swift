//
//  SampleListApp.swift
//  SampleListApp
//
//  Created by 김동현 on 4/15/26.
//

import AfterImage
import SwiftUI

@main
struct SampleListApp: App {
    
    init() {
        let configuration = AfterImageConfiguration(
            memoryCacheConfiguration: MemoryCacheConfiguration(
                countLimit: 250,
                totalCostLimit: 50 * 1024 * 1024
            ),
            diskCacheConfiguration: DiskCacheConfiguration(
                directoryURL: FileManager.default.urls(
                    for: .cachesDirectory,
                    in: .userDomainMask
                )[0]
                .appendingPathComponent("SampleListApp-AfterImage", isDirectory: true),
                defaultTTL: 7 * 24 * 60 * 60,
                countLimit: 1_000,
                totalSizeLimit: 200 * 1024 * 1024
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
