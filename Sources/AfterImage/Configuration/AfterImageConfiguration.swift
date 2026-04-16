//
//  AfterImageConfiguration.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Foundation

public struct AfterImageConfiguration: Sendable {
    /// 메모리 캐시 설정입니다.
    public let memoryCacheConfiguration: MemoryCacheConfiguration
    
    /// 디스크 캐시 설정입니다.
    public let diskCacheConfiguration: DiskCacheConfiguration
    
    public init(
        memoryCacheConfiguration: MemoryCacheConfiguration,
        diskCacheConfiguration: DiskCacheConfiguration
    ) {
        self.memoryCacheConfiguration = memoryCacheConfiguration
        self.diskCacheConfiguration = diskCacheConfiguration
    }
}

public extension AfterImageConfiguration {
    
    /// 기본 AfterImage 설정입니다.
    ///
    /// - Memory cache:
    ///   - count limit: 300
    ///   - total cost limit: 50MB
    ///
    /// - Disk cache:
    ///   - directory: Caches/AfterImage
    ///   - TTL: 7일
    ///   - count limit: 1,000
    ///   - total size limit: 200MB
    static let `default` = AfterImageConfiguration(
        memoryCacheConfiguration: MemoryCacheConfiguration(
            countLimit: 300,
            totalCostLimit: 50 * 1024 * 1024
        ),
        diskCacheConfiguration: DiskCacheConfiguration(
            directoryURL: Self.defaultDiskCacheDirectoryURL,
            defaultTTL: 7 * 24 * 60 * 60,
            countLimit: 1_000,
            totalSizeLimit: 200 * 1024 * 1024
        )
    )
    
    private static var defaultDiskCacheDirectoryURL: URL {
        let cachesDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        
        return cachesDirectory.appendingPathComponent(
            "AfterImage",
            isDirectory: true
        )
    }
}
