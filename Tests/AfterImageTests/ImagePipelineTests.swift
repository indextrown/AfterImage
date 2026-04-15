//
//  ImagePipelineTests.swift
//  AfterImageTests
//
//  Created by 김동현 on 4/15/26.
//

import Testing
import UIKit
@testable import AfterImage

struct ImagePipelineTests {
    @Test("memory hit이면 disk와 network를 거치지 않고 이미지를 반환한다")
    func memoryHitReturnsImageWithoutDiskAndNetworkLoad() async throws {
        let request = ImageRequest(url: URL(string: "https://example.com/image.png")!)
        let cacheKey = VariantKey(request: request).cacheKey
        let expectedImage = makeImage(size: CGSize(width: 10, height: 10))

        let memoryCache = LRUMemoryCache<CacheKey, UIImage>(
            countLimit: 10,
            totalCostLimit: 1_000_000
        )
        memoryCache.insertImage(expectedImage, key: cacheKey)

        let diskCache = MockDiskCache()
        let dataLoader = MockDataLoader()
        let imageDecoder = MockImageDecoder(image: makeImage(size: CGSize(width: 1, height: 1)))

        let pipeline = ImagePipeline(
            memoryCache: memoryCache,
            diskCache: diskCache,
            dataLoader: dataLoader,
            imageDecoder: imageDecoder
        )

        let image = try await pipeline.loadImage(request)

        #expect(image === expectedImage)
        #expect(await diskCache.dataCallCount() == 0)
        #expect(await dataLoader.loadCount() == 0)
        #expect(imageDecoder.decodeCount == 0)
    }

    @Test("disk hit이면 decode 후 memory cache에 저장하고 이미지를 반환한다")
    func diskHitDecodesAndStoresImageInMemory() async throws {
        let request = ImageRequest(url: URL(string: "https://example.com/image.png")!)
        let cacheKey = VariantKey(request: request).cacheKey
        let diskData = Data("disk-data".utf8)
        let decodedImage = makeImage(size: CGSize(width: 20, height: 20))

        let memoryCache = LRUMemoryCache<CacheKey, UIImage>(
            countLimit: 10,
            totalCostLimit: 1_000_000
        )

        let diskCache = MockDiskCache(initialStorage: [
            cacheKey.rawValue: diskData
        ])
        let dataLoader = MockDataLoader()
        let imageDecoder = MockImageDecoder(image: decodedImage)

        let pipeline = ImagePipeline(
            memoryCache: memoryCache,
            diskCache: diskCache,
            dataLoader: dataLoader,
            imageDecoder: imageDecoder
        )

        let image = try await pipeline.loadImage(request)

        #expect(image === decodedImage)
        #expect(memoryCache.value(key: cacheKey) === decodedImage)
        #expect(await dataLoader.loadCount() == 0)
        #expect(imageDecoder.decodeCount == 1)
    }

    @Test("cache miss이면 network data를 받아 decode 후 memory와 disk에 저장한다")
    func cacheMissLoadsFromNetworkAndStoresCaches() async throws {
        let request = ImageRequest(url: URL(string: "https://example.com/image.png")!)
        let cacheKey = VariantKey(request: request).cacheKey
        let networkData = Data("network-data".utf8)
        let decodedImage = makeImage(size: CGSize(width: 30, height: 30))

        let memoryCache = LRUMemoryCache<CacheKey, UIImage>(
            countLimit: 10,
            totalCostLimit: 1_000_000
        )

        let diskCache = MockDiskCache()
        let dataLoader = MockDataLoader(data: networkData)
        let imageDecoder = MockImageDecoder(image: decodedImage)

        let pipeline = ImagePipeline(
            memoryCache: memoryCache,
            diskCache: diskCache,
            dataLoader: dataLoader,
            imageDecoder: imageDecoder
        )

        let image = try await pipeline.loadImage(request)

        #expect(image === decodedImage)
        #expect(await dataLoader.loadCount() == 1)
        #expect(memoryCache.value(key: cacheKey) === decodedImage)
        #expect(await diskCache.storedData(key: cacheKey.rawValue) == networkData)
        #expect(imageDecoder.decodeCount == 1)
    }

    @Test("returnCacheDataDontLoad에서 cache miss이면 cacheMiss를 던진다")
    func returnCacheDataDontLoadThrowsCacheMissWhenCacheIsEmpty() async {
        let request = ImageRequest(
            url: URL(string: "https://example.com/image.png")!,
            cachePolicy: .returnCacheDataDontLoad
        )

        let pipeline = ImagePipeline(
            memoryCache: LRUMemoryCache<CacheKey, UIImage>(
                countLimit: 10,
                totalCostLimit: 1_000_000
            ),
            diskCache: MockDiskCache(),
            dataLoader: MockDataLoader(),
            imageDecoder: MockImageDecoder(image: makeImage(size: CGSize(width: 1, height: 1)))
        )

        await #expect(throws: ImagePipelineError.cacheMiss) {
            try await pipeline.loadImage(request)
        }
    }
    
    @Test("실제 URL 이미지를 network에서 받아 decode하고 memory와 disk에 저장한다")
    func realURLLoadsImageAndStoresCaches() async throws {
        let url = URL(string: "https://httpbin.org/image/png")!
        let request = ImageRequest(
            url: url,
            targetSize: CGSize(width: 80, height: 80),
            scale: 2
        )
        let cacheKey = VariantKey(request: request).cacheKey
        let (pipeline, memoryCache, diskCacheURL) = makeRealPipeline()
        
        defer {
            try? FileManager.default.removeItem(at: diskCacheURL)
        }
        
        let image = try await pipeline.loadImage(request)
        
        #expect(image.cgImage != nil)
        #expect(memoryCache.value(key: cacheKey) != nil)
        #expect(FileManager.default.fileExists(atPath: diskCacheURL.path))
    }
    
    @Test("실제 URL 이미지를 한 번 로드한 뒤 cacheOnly 요청으로 다시 조회한다")
    func realURLCacheOnlyRequestReturnsStoredImageAfterInitialLoad() async throws {
        let url = URL(string: "https://httpbin.org/image/png")!
        let initialRequest = ImageRequest(
            url: url,
            targetSize: CGSize(width: 80, height: 80),
            scale: 2
        )
        let cacheOnlyRequest = ImageRequest(
            url: url,
            targetSize: CGSize(width: 80, height: 80),
            scale: 2,
            cachePolicy: .returnCacheDataDontLoad
        )
        let (pipeline, _, diskCacheURL) = makeRealPipeline()
        
        defer {
            try? FileManager.default.removeItem(at: diskCacheURL)
        }
        
        let loadedImage = try await pipeline.loadImage(initialRequest)
        let cachedImage = try await pipeline.loadImage(cacheOnlyRequest)
        
        #expect(loadedImage.cgImage != nil)
        #expect(cachedImage.cgImage != nil)
    }
}

private actor MockDataLoader: DataLoaderType {
    private var count = 0
    private let data: Data

    init(data: Data = Data("mock-data".utf8)) {
        self.data = data
    }

    func data(url: URL) async throws -> Data {
        count += 1
        return data
    }

    func loadCount() -> Int {
        count
    }
}

private actor MockDiskCache: DiskCacheType {
    private var storage: [String: Data]
    private var dataCalls = 0

    init(initialStorage: [String: Data] = [:]) {
        self.storage = initialStorage
    }

    func data(key: String) async -> Data? {
        dataCalls += 1
        return storage[key]
    }

    func insert(_ data: Data, key: String, ttl: TimeInterval?) async throws {
        storage[key] = data
    }

    func removeData(key: String) async throws {
        storage.removeValue(forKey: key)
    }

    func removeAll() async throws {
        storage.removeAll()
    }

    func storedData(key: String) -> Data? {
        storage[key]
    }

    func dataCallCount() -> Int {
        dataCalls
    }
}

private final class MockImageDecoder: ImageDecoderType, @unchecked Sendable {
    let image: UIImage
    private(set) var decodeCount = 0

    init(image: UIImage) {
        self.image = image
    }

    func decode(
        _ data: Data,
        targetSize: CGSize?,
        scale: CGFloat
    ) throws -> UIImage {
        decodeCount += 1
        return image
    }
}

private func makeImage(size: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { context in
        UIColor.red.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

private func makeRealPipeline() -> (
    pipeline: ImagePipeline,
    memoryCache: LRUMemoryCache<CacheKey, UIImage>,
    diskCacheURL: URL
) {
    let memoryCache = LRUMemoryCache<CacheKey, UIImage>(
        countLimit: 100,
        totalCostLimit: 20 * 1024 * 1024
    )
    
    let diskCacheURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    
    let diskCache = DiskCache(
        configuration: DiskCacheConfiguration(
            directoryURL: diskCacheURL,
            defaultTTL: 60 * 60,
            countLimit: 100,
            totalSizeLimit: 20 * 1024 * 1024
        )
    )
    
    let pipeline = ImagePipeline(
        memoryCache: memoryCache,
        diskCache: diskCache,
        dataLoader: URLSessionDataLoader(),
        imageDecoder: ImageDecoder()
    )
    
    return (pipeline, memoryCache, diskCacheURL)
}
