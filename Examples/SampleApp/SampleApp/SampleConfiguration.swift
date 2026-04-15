//
//  SampleConfiguration.swift
//  SampleApp
//
//  Created by 김동현 on 4/15/26.
//

import AfterImage
import CoreGraphics
import Foundation

struct SampleImage: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let url: URL
}

enum SampleConfiguration {
    static let displayScale: CGFloat = 2
    static let featuredTargetSize = CGSize(width: 320, height: 200)
    static let thumbnailTargetSize = CGSize(width: 84, height: 84)
    static let cachePolicyTargetSize = CGSize(width: 160, height: 160)
    
    static let afterImageConfiguration = AfterImageConfiguration(
        memoryCacheConfiguration: MemoryCacheConfiguration(
            countLimit: 200,
            totalCostLimit: 50 * 1024 * 1024
        ),
        diskCacheConfiguration: DiskCacheConfiguration(
            directoryURL: diskCacheDirectoryURL,
            defaultTTL: 7 * 24 * 60 * 60,
            countLimit: 1_000,
            totalSizeLimit: 200 * 1024 * 1024
        )
    )
    
    static let images: [SampleImage] = [
        SampleImage(
            id: 1,
            title: "Featured image",
            subtitle: "Network -> decode -> memory + disk",
            url: makeURL("https://picsum.photos/id/10/900/600")
        ),
        SampleImage(
            id: 2,
            title: "Cache policy target",
            subtitle: "Use the buttons above to compare cache hit and miss",
            url: makeURL("https://picsum.photos/id/20/600/600")
        ),
        SampleImage(
            id: 3,
            title: "Downsampled thumbnail",
            subtitle: "Requested as an 84pt display image",
            url: makeURL("https://picsum.photos/id/30/600/600")
        ),
        SampleImage(
            id: 4,
            title: "Independent variant",
            subtitle: "Different URL creates a different cache key",
            url: makeURL("https://picsum.photos/id/40/600/600")
        )
    ]
    
    static var featuredImage: SampleImage {
        images[0]
    }
    
    static var cachePolicyImage: SampleImage {
        images[1]
    }
    
    private static func makeURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid sample image URL: \(string)")
        }
        return url
    }
    
    private static var diskCacheDirectoryURL: URL {
        let cachesDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        
        return cachesDirectory.appendingPathComponent(
            "AfterImageSampleApp",
            isDirectory: true
        )
    }
}
