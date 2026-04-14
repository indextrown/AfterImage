//
//  DiskCache.swift
//  AfterImage
//
//  Created by 김동현 on 4/13/26.
//

import Foundation
import CryptoKit

public actor DiskCache: DiskCacheType {
    
    
    /// 개별 캐시 항목의 메타데이터를 표현하는 내부 타입입니다.
    ///
    /// 데이터 자체는 `.data` 파일에 저장하고,
    /// 이 구조체는 `.json` 파일로 직렬화되어 함께 저장됩니다.
    private struct MetaData: Codable, Sendable {
        
        /// 원본 캐시 키입니다.
        ///
        /// 디버깅이나 추적 용도로 함께 보관합니다.
        let key: String
        
        /// 실제 저장 파일 이름의 베이스 값입니다.
        ///
        /// 확장자는 포함하지 않으며,
        /// 데이터 파일은 `.data`, 메타데이터 파일은 `.json` 확장자를 사용합니다.
        let fileName: String
        
        /// 저장된 데이터의 바이트 크기입니다.
        ///
        /// 전체 디스크 사용량 계산에 사용됩니다.
        let size: Int
        
        /// 항목이 처음 생성된 시각입니다.
        let createdAt: Date
        
        /// 마지막으로 조회된 시각입니다.
        ///
        /// LRU(Least Recently Used) 방식의 정리 기준으로 사용됩니다.
        var lastAccessedAt: Date
        
        /// 항목의 만료 시각입니다.
        ///
        /// `nil`이면 만료되지 않는 항목으로 간주합니다.
        let expiresAt: Date?
    }
    
    /// 디스크 캐시 저장 위치와 정책을 담은 설정값입니다.
    private let configuration: DiskCacheConfiguration
    
    /// 파일 생성, 삭제, 디렉터리 탐색을 담당하는 파일 매니저입니다.
    private let fileManager: FileManager
    
    /// 디스크 캐시를 생성합니다.
    ///
    /// - Parameters:
    ///   - configuration: 저장 디렉터리, TTL, 개수 제한, 용량 제한을 포함한 캐시 설정입니다.
    ///   - fileManager: 파일 시스템 접근에 사용할 `FileManager`입니다.
    ///                  테스트 시 커스텀 인스턴스를 주입할 수 있습니다.
    public init(
        configuration: DiskCacheConfiguration,
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
    }
}

extension DiskCache {
    
    /// 캐시 디렉터리가 존재하지 않으면 생성합니다.
    ///
    /// 디스크 캐시 사용 전 반드시 저장 디렉터리가 준비되어 있어야 하므로,
    /// 저장/조회 시점에 선행 호출됩니다.
    ///
    /// - Throws: 디렉터리 생성 중 오류가 발생하면 throw합니다.
    private func createDirectoryIfNeeded() throws {
        guard !fileManager.fileExists(atPath: configuration.directoryURL.path) else {
            return
        }
        
        try fileManager.createDirectory(
            at: configuration.directoryURL,
            withIntermediateDirectories: true
        )
    }
    
    /// 주어진 키를 파일 시스템에서 안전하게 사용할 수 있는 해시 파일명으로 변환합니다.
    ///
    /// 키 원문을 그대로 파일명으로 사용하지 않고 SHA-256 해시 문자열로 변환해
    /// 파일명 길이, 특수문자, 경로 충돌 문제를 줄입니다.
    ///
    /// - Parameter key: 원본 캐시 키입니다.
    /// - Returns: SHA-256 해시 기반의 16진수 문자열 파일명입니다.
    private func hashedFileName(key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// 데이터 파일의 URL을 생성합니다.
    ///
    /// - Parameter fileName: 확장자를 제외한 베이스 파일명입니다.
    /// - Returns: `.data` 확장자를 갖는 실제 데이터 파일 URL입니다.
    private func dataURL(fileName: String) -> URL {
        configuration.directoryURL
            .appendingPathComponent(fileName)
            .appendingPathExtension("data")
    }
    
    /// 메타데이터 파일의 URL을 생성합니다.
    ///
    /// - Parameter fileName: 확장자를 제외한 베이스 파일명입니다.
    /// - Returns: `.json` 확장자를 갖는 메타데이터 파일 URL입니다.
    private func metadataURL(fileName: String) -> URL {
        configuration.directoryURL
            .appendingPathComponent(fileName)
            .appendingPathExtension("json")
    }
    
    /// 지정한 메타데이터 파일을 읽어 `MetaData`로 디코딩합니다.
      ///
      /// - Parameter url: 메타데이터 파일 URL입니다.
      /// - Returns: 디코딩된 메타데이터 객체입니다.
      /// - Throws: 파일 읽기 또는 JSON 디코딩 실패 시 오류를 throw합니다.
    private func loadMetadata(url: URL) throws -> MetaData {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MetaData.self, from: data)
    }
    
    /// 메타데이터를 JSON 파일로 저장합니다.
    ///
    /// `.atomic` 옵션을 사용해 쓰기 도중 파일이 깨질 가능성을 줄입니다.
    ///
    /// - Parameters:
    ///   - metadata: 저장할 메타데이터입니다.
    ///   - url: 메타데이터를 저장할 파일 URL입니다.
    /// - Throws: JSON 인코딩 또는 파일 저장 실패 시 오류를 throw합니다.
    private func saveMetadata(_ metadata: MetaData, url: URL) throws {
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: url, options: .atomic)
    }
    
    /// 메타데이터 기준으로 캐시 항목이 만료되었는지 확인합니다.
    ///
    /// - Parameter metadata: 검사할 캐시 항목의 메타데이터입니다.
    /// - Returns:
    ///   - `expiresAt`이 없으면 `false`
    ///   - 현재 시각이 `expiresAt` 이상이면 `true`
    private func isExpired(_ metadata: MetaData) -> Bool {
        guard let expiresAt = metadata.expiresAt else {
            return false
        }
        
        return Date() >= expiresAt
    }
    
    /// 주어진 파일명에 해당하는 데이터 파일과 메타데이터 파일을 함께 삭제합니다.
    ///
    /// 파일이 존재하는 경우에만 삭제를 시도합니다.
    ///
    /// - Parameter fileName: 확장자를 제외한 베이스 파일명입니다.
    /// - Throws: 파일 삭제 실패 시 오류를 throw합니다.
    private func removeFiles(fileName: String) throws {
        let urls = [
            dataURL(fileName: fileName),
            metadataURL(fileName: fileName)
        ]
        
        for url in urls where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    /// 캐시 디렉터리 안의 모든 메타데이터 파일을 읽어 배열로 반환합니다.
    ///
    /// 손상된 메타데이터 파일이 발견되면,
    /// 해당 메타데이터와 연결된 데이터 파일까지 함께 제거해
    /// orphan 파일이 남지 않도록 정리합니다.
    ///
    /// - Returns: 현재 디스크 캐시에 남아 있는 메타데이터 목록입니다.
    /// - Throws: 디렉터리 조회 실패 시 오류를 throw합니다.
    private func loadAllMetadata() throws -> [MetaData] {
        guard fileManager.fileExists(atPath: configuration.directoryURL.path) else {
            return []
        }
        
        let urls = try fileManager.contentsOfDirectory(
            at: configuration.directoryURL,
            includingPropertiesForKeys: nil
        )
        
        var metadataList: [MetaData] = []
        
        for url in urls where url.pathExtension == "json" {
            do {
                let metadata = try loadMetadata(url: url)
                metadataList.append(metadata)
            } catch {
                let fileName = url.deletingPathExtension().lastPathComponent
                try? removeFiles(fileName: fileName)
            }
        }
        
        return metadataList
    }
    
    /// 캐시 정책을 위반한 항목을 정리합니다.
    ///
    /// 정리 순서는 다음과 같습니다.
    /// 1. 먼저 TTL이 지난 만료 항목을 제거합니다.
    /// 2. 남은 항목의 총 개수와 총 용량을 계산합니다.
    /// 3. 제한을 초과하면 `lastAccessedAt`이 가장 오래된 항목부터 제거합니다.
    ///
    /// 즉, 만료 항목 제거와 LRU 기반 제거를 함께 수행하는 메서드입니다.
    ///
    /// - Throws: 메타데이터 로드나 파일 삭제 중 오류가 발생하면 throw합니다.
    private func evictIfNeeded_legacy() throws {
        let metadataList = try loadAllMetadata()
        for metadata in metadataList where isExpired(metadata) {
            try removeFiles(fileName: metadata.fileName)
        }
        
        var remainingMetadata = try loadAllMetadata()
        var totalSize = remainingMetadata.reduce(0) { $0 + $1.size }
        
        // 최근 접근한 항목이 앞, 가장 오래된 항목이 뒤로 가도록 정렬
        remainingMetadata.sort {
            $0.lastAccessedAt > $1.lastAccessedAt
        }
        
        // 개수 제한 또는 전체 용량 제한을 만족할 때까지,
        // 가장 오래 접근하지 않은 항목부터 순서대로 제거합니다.
        while remainingMetadata.count > configuration.countLimit ||
              totalSize > configuration.totalSizeLimit {
            guard let metadata = remainingMetadata.last else {
                return
            }
            
            try removeFiles(fileName: metadata.fileName)
            totalSize -= metadata.size
            remainingMetadata.removeLast()
        }
    }
    
    /// 캐시 정책을 위반한 항목을 정리합니다.
    ///
    /// 정리 순서는 다음과 같습니다.
    /// 1. 먼저 TTL이 지난 만료 항목을 제거합니다.
    /// 2. 남은 항목의 총 개수와 총 용량을 계산합니다.
    /// 3. 제한을 초과하면 `lastAccessedAt`이 가장 오래된 항목부터 제거합니다.
    ///
    /// 즉, 만료 항목 제거와 LRU 기반 제거를 함께 수행하는 메서드입니다.
    ///
    /// - Throws: 메타데이터 로드나 파일 삭제 중 오류가 발생하면 throw합니다.
    private func evictIfNeeded() throws {
        let metadataList = try loadAllMetadata()
        
        var remainingMetadata: [MetaData] = []
        remainingMetadata.reserveCapacity(metadataList.count)
        
        for metadata in metadataList {
            if isExpired(metadata) {
                try? removeFiles(fileName: metadata.fileName)
            } else {
                remainingMetadata.append(metadata)
            }
        }
        
        var totalSize = remainingMetadata.reduce(0) { $0 + $1.size }
        
        // 최근 접근한 항목이 앞, 가장 오래된 항목이 뒤로 가도록 정렬
        remainingMetadata.sort {
            $0.lastAccessedAt > $1.lastAccessedAt
        }
        
        // 개수 제한 또는 전체 용량 제한을 만족할 때까지,
        // 가장 오래 접근하지 않은 항목부터 순서대로 제거합니다.
        while remainingMetadata.count > configuration.countLimit ||
                totalSize > configuration.totalSizeLimit {
            guard let metadata = remainingMetadata.last else {
                return
            }
            
            try removeFiles(fileName: metadata.fileName)
            totalSize -= metadata.size
            remainingMetadata.removeLast()
        }
    }
}

public extension DiskCache {
    func data(key: String) async -> Data? {
        do {
            try createDirectoryIfNeeded()
            let fileName = hashedFileName(key: key)
            let dataURL = dataURL(fileName: fileName)
            let metadataURL = metadataURL(fileName: fileName)
            guard fileManager.fileExists(atPath: dataURL.path) else {
                return nil
            }
            
            var metadata = try loadMetadata(url: metadataURL)
            if isExpired(metadata) {
                try removeFiles(fileName: fileName)
                return nil
            }
            
            let data = try Data(contentsOf: dataURL)
            metadata.lastAccessedAt = Date()
            try saveMetadata(metadata, url: metadataURL)
            return data
        } catch {
            try? await removeData(key: key)
            return nil
        }
    }
    
    func insert(_ data: Data, key: String, ttl: TimeInterval?) async throws {
        try createDirectoryIfNeeded()
        
        let now = Date()
        let fileName = hashedFileName(key: key)
        let dataURL = dataURL(fileName: fileName)
        let metadataURL = metadataURL(fileName: fileName)
        
        let effectiveTTL = ttl ?? configuration.defaultTTL
        
        let metadata = MetaData(
            key: key,
            fileName: fileName,
            size: data.count,
            createdAt: now,
            lastAccessedAt: now,
            expiresAt: effectiveTTL.map { now.addingTimeInterval($0) }
        )
        
        do {
            try data.write(to: dataURL, options: .atomic)
            try saveMetadata(metadata, url: metadataURL)
            try evictIfNeeded()
        } catch {
            try? removeFiles(fileName: fileName)
            throw error
        }
    }
    
    func removeData(key: String) async throws {
        let fileName = hashedFileName(key: key)
        try removeFiles(fileName: fileName)
    }
    
    func removeAll() async throws {
        guard fileManager.fileExists(atPath: configuration.directoryURL.path) else {
            return
        }
        
        let urls = try fileManager.contentsOfDirectory(
            at: configuration.directoryURL,
            includingPropertiesForKeys: nil
        )
        
        for url in urls {
            try fileManager.removeItem(at: url)
        }
    }
}
