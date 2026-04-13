//
//  DiskCacheTests.swift
//  AfterImage
//
//  Created by 김동현 on 4/13/26.
//

import Foundation
import CryptoKit
import Testing
@testable import AfterImage

struct DiskCacheTests {
    
    @Test("저장한 데이터를 동일 키로 조회할 수 있다")
    func insertAndRetrieveData() async throws {
        // Given
        let (cache, directoryURL) = makeCache()
        let key = "image_key"
        let expectedData = Data("hello-disk-cache".utf8)
        
        // When
        try await cache.insert(expectedData, key: key, ttl: nil)
        let retrievedData = await cache.data(key: key)
        
        // Then
        #expect(retrievedData == expectedData)
        #expect(fileExists(forKey: key, in: directoryURL))
        #expect(metadataExists(forKey: key, in: directoryURL))
    }

    @Test("TTL이 지난 데이터는 nil을 반환하고 파일에서 제거된다")
    func expiredDataReturnsNil() async throws {
        // Given
        let (cache, directoryURL) = makeCache(defaultTTL: nil)
        let key = "expired_key"
        let data = Data("expired".utf8)
        
        try await cache.insert(data, key: key, ttl: 0.1)
        
        // TTL 경과 대기
        try await sleep(milliseconds: 200)
        
        // When
        let retrievedData = await cache.data(key: key)
        
        // Then
        #expect(retrievedData == nil)
        #expect(fileExists(forKey: key, in: directoryURL) == false)
        #expect(metadataExists(forKey: key, in: directoryURL) == false)
    }

    @Test("countLimit 초과 시 오래 접근하지 않은 항목부터 제거된다")
    func evictsLeastRecentlyAccessedWhenCountLimitExceeded() async throws {
        // Given
        let (cache, directoryURL) = makeCache(
            countLimit: 2,
            totalSizeLimit: 10_000
        )
        
        let keyA = "A"
        let keyB = "B"
        let keyC = "C"
        
        let dataA = Data("A".utf8)
        let dataB = Data("B".utf8)
        let dataC = Data("C".utf8)
        
        try await cache.insert(dataA, key: keyA, ttl: nil)
        try await sleep(milliseconds: 20)
        
        try await cache.insert(dataB, key: keyB, ttl: nil)
        try await sleep(milliseconds: 20)
        
        // A를 다시 조회해서 최근 접근 상태로 갱신
        _ = await cache.data(key: keyA)
        try await sleep(milliseconds: 20)
        
        // When
        try await cache.insert(dataC, key: keyC, ttl: nil)
        
        let resultA = await cache.data(key: keyA)
        let resultB = await cache.data(key: keyB)
        let resultC = await cache.data(key: keyC)
        
        // Then
        #expect(resultA == dataA)
        #expect(resultB == nil)
        #expect(resultC == dataC)
        
        #expect(fileExists(forKey: keyA, in: directoryURL))
        #expect(fileExists(forKey: keyB, in: directoryURL) == false)
        #expect(fileExists(forKey: keyC, in: directoryURL))
    }

    @Test("totalSizeLimit 초과 시 오래 접근하지 않은 항목부터 제거된다")
    func evictsLeastRecentlyAccessedWhenTotalSizeLimitExceeded() async throws {
        // Given
        let (cache, directoryURL) = makeCache(
            countLimit: 10,
            totalSizeLimit: 10
        )
        
        let keyA = "A"
        let keyB = "B"
        let keyC = "C"
        
        let dataA = Data("1234".utf8) // 4 bytes
        let dataB = Data("5678".utf8) // 4 bytes
        let dataC = Data("90AB".utf8) // 4 bytes
        
        try await cache.insert(dataA, key: keyA, ttl: nil)
        try await sleep(milliseconds: 20)
        
        try await cache.insert(dataB, key: keyB, ttl: nil)
        try await sleep(milliseconds: 20)
        
        // A를 다시 접근해서 B가 더 오래된 항목이 되도록 만듦
        _ = await cache.data(key: keyA)
        try await sleep(milliseconds: 20)
        
        // When
        try await cache.insert(dataC, key: keyC, ttl: nil)
        
        let resultA = await cache.data(key: keyA)
        let resultB = await cache.data(key: keyB)
        let resultC = await cache.data(key: keyC)
        
        // Then
        #expect(resultA == dataA)
        #expect(resultB == nil)
        #expect(resultC == dataC)
        
        #expect(fileExists(forKey: keyA, in: directoryURL))
        #expect(fileExists(forKey: keyB, in: directoryURL) == false)
        #expect(fileExists(forKey: keyC, in: directoryURL))
    }

    @Test("metadata가 손상된 경우 nil을 반환하고 방어적으로 정리한다")
    func corruptedMetadataIsRemoved() async throws {
        // Given
        let (cache, directoryURL) = makeCache()
        let key = "corrupted_key"
        let data = Data("valid-data".utf8)
        
        try await cache.insert(data, key: key, ttl: nil)
        
        let fileName = hashedFileName(for: key)
        let metadataURL = directoryURL
            .appendingPathComponent(fileName)
            .appendingPathExtension("json")
        
        // metadata를 고의로 손상
        try Data("invalid-json".utf8).write(to: metadataURL, options: .atomic)
        
        // When
        let retrievedData = await cache.data(key: key)
        
        // Then
        #expect(retrievedData == nil)
        #expect(fileExists(forKey: key, in: directoryURL) == false)
        #expect(metadataExists(forKey: key, in: directoryURL) == false)
    }

    @Test("removeAll 호출 시 모든 캐시 파일이 제거된다")
    func removeAllDeletesAllFiles() async throws {
        // Given
        let (cache, directoryURL) = makeCache()
        
        try await cache.insert(Data("first".utf8), key: "key1", ttl: nil)
        try await cache.insert(Data("second".utf8), key: "key2", ttl: nil)
        try await cache.insert(Data("third".utf8), key: "key3", ttl: nil)
        
        let beforeURLs = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        #expect(beforeURLs.isEmpty == false)
        
        // When
        try await cache.removeAll()
        
        let afterURLs = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        
        let result1 = await cache.data(key: "key1")
        let result2 = await cache.data(key: "key2")
        let result3 = await cache.data(key: "key3")
        
        // Then
        #expect(afterURLs.isEmpty)
        #expect(result1 == nil)
        #expect(result2 == nil)
        #expect(result3 == nil)
    }
    
    @Test("파일명으로 안전하지 않은 문자가 포함된 키도 해시 파일명으로 안전하게 저장 및 조회된다")
    func storesAndRetrievesDataForUnsafeKey() async throws {
        // Given
        let (cache, directoryURL) = makeCache()
        let key = "https://example.com/images/😀/프로필.png?size=200x200&token=a/b/c&name=hello world"
        let expectedData = Data("unsafe-key-data".utf8)

        // When
        try await cache.insert(expectedData, key: key, ttl: nil)
        let retrievedData = await cache.data(key: key)

        // Then
        #expect(retrievedData == expectedData)
        #expect(fileExists(forKey: key, in: directoryURL))
        #expect(metadataExists(forKey: key, in: directoryURL))
    }
}

// MARK: - Helpers
private extension DiskCacheTests {
    
    func sleep(milliseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    }
    
    func makeCache(
        defaultTTL: TimeInterval? = 60 * 60,
        countLimit: Int = 100,
        totalSizeLimit: Int = 1024 * 1024
    ) -> (DiskCache, URL) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        let configuration = DiskCacheConfiguration(
            directoryURL: directoryURL,
            defaultTTL: defaultTTL,
            countLimit: countLimit,
            totalSizeLimit: totalSizeLimit
        )
        
        let cache = DiskCache(configuration: configuration)
        return (cache, directoryURL)
    }
    
    func hashedFileName(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    func dataFileURL(forKey key: String, in directoryURL: URL) -> URL {
        directoryURL
            .appendingPathComponent(hashedFileName(for: key))
            .appendingPathExtension("data")
    }
    
    func metadataFileURL(forKey key: String, in directoryURL: URL) -> URL {
        directoryURL
            .appendingPathComponent(hashedFileName(for: key))
            .appendingPathExtension("json")
    }
    
    func fileExists(forKey key: String, in directoryURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: dataFileURL(forKey: key, in: directoryURL).path)
    }
    
    func metadataExists(forKey key: String, in directoryURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: metadataFileURL(forKey: key, in: directoryURL).path)
    }
}
