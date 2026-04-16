//
//  ImageListSection.swift
//  SampleListApp
//
//  Created by 김동현 on 4/15/26.
//

import Foundation

struct ImageListSection: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let items: [ImageItem]
    
    static let samples: [ImageListSection] = [
        ImageListSection(
            id: 1,
            title: "UIKit Image List",
            subtitle: "UIImageView.setAfterImage + reusable cells",
            items: ImageItem.tableViewSamples
        ),
        ImageListSection(
            id: 2,
            title: "Cache Revisit",
            subtitle: "Repeated URLs reuse memory or disk cache",
            items: ImageItem.cacheRevisitSamples
        )
    ]
}

struct ImageItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let url: URL
    
    static let tableViewSamples: [ImageItem] = [
        ImageItem(
            id: 1,
            title: "Mountain",
            subtitle: "App-level shared configuration",
            url: makeURL("https://picsum.photos/id/1018/700/700")
        ),
        ImageItem(
            id: 2,
            title: "River",
            subtitle: "UITableViewCell reuse safe loading",
            url: makeURL("https://picsum.photos/id/1015/700/700")
        ),
        ImageItem(
            id: 3,
            title: "Forest",
            subtitle: "Downsampled to thumbnail size",
            url: makeURL("https://picsum.photos/id/1020/700/700")
        ),
        ImageItem(
            id: 4,
            title: "Sea",
            subtitle: "Memory -> disk -> network",
            url: makeURL("https://picsum.photos/id/1011/700/700")
        )
    ]
    
    static let cacheRevisitSamples: [ImageItem] = [
        ImageItem(
            id: 101,
            title: "Mountain first load",
            subtitle: "First visit stores decoded image and data",
            url: makeURL("https://picsum.photos/id/1018/700/700")
        ),
        ImageItem(
            id: 102,
            title: "Mountain revisit",
            subtitle: "Same URL should return from cache",
            url: makeURL("https://picsum.photos/id/1018/700/700")
        ),
        ImageItem(
            id: 103,
            title: "River first load",
            subtitle: "First visit can fall through to network",
            url: makeURL("https://picsum.photos/id/1015/700/700")
        ),
        ImageItem(
            id: 104,
            title: "River revisit",
            subtitle: "Same URL and size reuse the cached variant",
            url: makeURL("https://picsum.photos/id/1015/700/700")
        ),
        ImageItem(
            id: 105,
            title: "Forest first load",
            subtitle: "Scroll away and return to compare behavior",
            url: makeURL("https://picsum.photos/id/1020/700/700")
        ),
        ImageItem(
            id: 106,
            title: "Forest revisit",
            subtitle: "Expected path: memory cache, then disk cache",
            url: makeURL("https://picsum.photos/id/1020/700/700")
        )
    ]
    
    private static func makeURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid image URL: \(string)")
        }
        return url
    }
}
