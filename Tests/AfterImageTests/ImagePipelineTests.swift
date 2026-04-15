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
    
    @Test("disk data decode 실패는 corrupted disk로 보고 제거 후 network fallback한다")
    func diskDecodeFailureRemovesDiskDataAndFallsBackToNetwork() async throws {
        let request = ImageRequest(url: URL(string: "https://example.com/image.png")!)
        let cacheKey = VariantKey(request: request).cacheKey
        let diskData = Data("corrupted-disk-data".utf8)
        let networkData = Data("network-data".utf8)
        let decodedImage = makeImage(size: CGSize(width: 20, height: 20))
        
        let diskCache = MockDiskCache(initialStorage: [
            cacheKey.rawValue: diskData
        ])
        let dataLoader = MockDataLoader(data: networkData)
        let imageDecoder = FailingOnceImageDecoder(image: decodedImage)
        
        let pipeline = ImagePipeline(
            memoryCache: LRUMemoryCache<CacheKey, UIImage>(
                countLimit: 10,
                totalCostLimit: 1_000_000
            ),
            diskCache: diskCache,
            dataLoader: dataLoader,
            imageDecoder: imageDecoder
        )
        
        let image = try await pipeline.loadImage(request)
        
        #expect(image === decodedImage)
        #expect(await diskCache.removeCallCount() == 1)
        #expect(await diskCache.storedData(key: cacheKey.rawValue) == networkData)
        #expect(await dataLoader.loadCount() == 1)
        #expect(imageDecoder.decodeCount == 2)
    }
    
    @Test("disk hit 후 processor 실패는 disk를 제거하거나 network fallback하지 않는다")
    func diskProcessorFailureDoesNotRemoveDiskDataOrFallbackToNetwork() async throws {
        let request = ImageRequest(
            url: URL(string: "https://example.com/image.png")!,
            processors: [FailingImageProcessor()]
        )
        let cacheKey = VariantKey(request: request).cacheKey
        let diskData = Data("valid-disk-data".utf8)
        let decodedImage = makeImage(size: CGSize(width: 20, height: 20))
        
        let diskCache = MockDiskCache(initialStorage: [
            cacheKey.rawValue: diskData
        ])
        let dataLoader = MockDataLoader(data: Data("network-data".utf8))
        let imageDecoder = MockImageDecoder(image: decodedImage)
        
        let pipeline = ImagePipeline(
            memoryCache: LRUMemoryCache<CacheKey, UIImage>(
                countLimit: 10,
                totalCostLimit: 1_000_000
            ),
            diskCache: diskCache,
            dataLoader: dataLoader,
            imageDecoder: imageDecoder
        )
        
        await #expect(throws: TestProcessorError.failed) {
            try await pipeline.loadImage(request)
        }
        
        #expect(await diskCache.removeCallCount() == 0)
        #expect(await diskCache.storedData(key: cacheKey.rawValue) == diskData)
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
    
    @Test("동일 request가 동시에 여러 번 들어오면 network load는 한 번만 수행된다")
    func concurrentSameRequestsShareSingleInFlightTask() async throws {
        let request = ImageRequest(url: URL(string: "https://example.com/image.png")!)
        let decodedImage = makeImage(size: CGSize(width: 40, height: 40))
        
        let memoryCache = LRUMemoryCache<CacheKey, UIImage>(
            countLimit: 10,
            totalCostLimit: 1_000_000
        )
        let dataLoader = MockDataLoader(
            data: Data("network-data".utf8),
            delayNanoseconds: 100_000_000
        )
        let imageDecoder = MockImageDecoder(image: decodedImage)
        
        let pipeline = ImagePipeline(
            memoryCache: memoryCache,
            diskCache: MockDiskCache(),
            dataLoader: dataLoader,
            imageDecoder: imageDecoder
        )
        
        async let first = pipeline.loadImage(request)
        async let second = pipeline.loadImage(request)
        async let third = pipeline.loadImage(request)
        
        let images = try await [first, second, third]
        
        #expect(images[0] === decodedImage)
        #expect(images[1] === decodedImage)
        #expect(images[2] === decodedImage)
        #expect(await dataLoader.loadCount() == 1)
        #expect(imageDecoder.decodeCount == 1)
    }
    
    @Test("동일 request가 동시에 disk hit되면 disk read와 decode는 한 번만 수행된다")
    func concurrentSameDiskHitRequestsShareSingleInFlightTask() async throws {
        let request = ImageRequest(url: URL(string: "https://example.com/image.png")!)
        let cacheKey = VariantKey(request: request).cacheKey
        let decodedImage = makeImage(size: CGSize(width: 40, height: 40))
        
        let memoryCache = LRUMemoryCache<CacheKey, UIImage>(
            countLimit: 10,
            totalCostLimit: 1_000_000
        )
        let diskCache = MockDiskCache(
            initialStorage: [
                cacheKey.rawValue: Data("disk-data".utf8)
            ],
            delayNanoseconds: 100_000_000
        )
        let dataLoader = MockDataLoader()
        let imageDecoder = MockImageDecoder(image: decodedImage)
        
        let pipeline = ImagePipeline(
            memoryCache: memoryCache,
            diskCache: diskCache,
            dataLoader: dataLoader,
            imageDecoder: imageDecoder
        )
        
        async let first = pipeline.loadImage(request)
        async let second = pipeline.loadImage(request)
        async let third = pipeline.loadImage(request)
        
        let images = try await [first, second, third]
        
        #expect(images[0] === decodedImage)
        #expect(images[1] === decodedImage)
        #expect(images[2] === decodedImage)
        #expect(await diskCache.dataCallCount() == 1)
        #expect(await dataLoader.loadCount() == 0)
        #expect(imageDecoder.decodeCount == 1)
    }
    
    @Test("같은 URL이라도 variant가 다르면 서로 다른 in-flight 작업으로 처리된다")
    func concurrentDifferentVariantsDoNotShareInFlightTask() async throws {
        let url = URL(string: "https://example.com/image.png")!
        let smallRequest = ImageRequest(
            url: url,
            targetSize: CGSize(width: 80, height: 80),
            scale: 2
        )
        let largeRequest = ImageRequest(
            url: url,
            targetSize: CGSize(width: 160, height: 160),
            scale: 2
        )
        let decodedImage = makeImage(size: CGSize(width: 40, height: 40))
        
        let memoryCache = LRUMemoryCache<CacheKey, UIImage>(
            countLimit: 10,
            totalCostLimit: 1_000_000
        )
        let dataLoader = MockDataLoader(
            data: Data("network-data".utf8),
            delayNanoseconds: 100_000_000
        )
        
        let pipeline = ImagePipeline(
            memoryCache: memoryCache,
            diskCache: MockDiskCache(),
            dataLoader: dataLoader,
            imageDecoder: MockImageDecoder(image: decodedImage)
        )
        
        async let first = pipeline.loadImage(smallRequest)
        async let second = pipeline.loadImage(largeRequest)
        
        _ = try await [first, second]
        
        #expect(await dataLoader.loadCount() == 2)
    }
    
    @Test("in-flight 작업이 실패하면 다음 요청에서 새 작업을 다시 시작한다")
    func failedInFlightTaskIsRemovedAndNextRequestCanRetry() async throws {
        let request = ImageRequest(url: URL(string: "https://example.com/image.png")!)
        let decodedImage = makeImage(size: CGSize(width: 40, height: 40))
        let dataLoader = FailingOnceDataLoader(successData: Data("network-data".utf8))
        
        let pipeline = ImagePipeline(
            memoryCache: LRUMemoryCache<CacheKey, UIImage>(
                countLimit: 10,
                totalCostLimit: 1_000_000
            ),
            diskCache: MockDiskCache(),
            dataLoader: dataLoader,
            imageDecoder: MockImageDecoder(image: decodedImage)
        )
        
        do {
            _ = try await pipeline.loadImage(request)
            #expect(Bool(false), "Expected URLError.notConnectedToInternet")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            #expect(Bool(false), "Expected URLError, but received \(error)")
        }
        
        let image = try await pipeline.loadImage(request)
        
        #expect(image === decodedImage)
        #expect(await dataLoader.loadCount() == 2)
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
        let cgImage = try #require(image.cgImage)
        let maxPixelSize = max(cgImage.width, cgImage.height)
        
        #expect(image.scale == 2)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
        #expect(maxPixelSize <= 160)
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
        let loadedCGImage = try #require(loadedImage.cgImage)
        let cachedCGImage = try #require(cachedImage.cgImage)
        
        #expect(loadedImage === cachedImage)
        #expect(loadedImage.scale == 2)
        #expect(cachedImage.scale == 2)
        #expect(max(loadedCGImage.width, loadedCGImage.height) <= 160)
        #expect(max(cachedCGImage.width, cachedCGImage.height) <= 160)
    }
}

private actor MockDataLoader: DataLoaderType {
    private var count = 0
    private let data: Data
    private let delayNanoseconds: UInt64?

    init(
        data: Data = Data("mock-data".utf8),
        delayNanoseconds: UInt64? = nil
    ) {
        self.data = data
        self.delayNanoseconds = delayNanoseconds
    }

    func data(url: URL) async throws -> Data {
        count += 1
        
        if let delayNanoseconds {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        
        return data
    }

    func loadCount() -> Int {
        count
    }
}

private actor FailingOnceDataLoader: DataLoaderType {
    private var count = 0
    private let successData: Data
    
    init(successData: Data) {
        self.successData = successData
    }
    
    func data(url: URL) async throws -> Data {
        count += 1
        
        if count == 1 {
            throw URLError(.notConnectedToInternet)
        }
        
        return successData
    }
    
    func loadCount() -> Int {
        count
    }
}

private actor MockDiskCache: DiskCacheType {
    private var storage: [String: Data]
    private var dataCalls = 0
    private var removeCalls = 0
    private let delayNanoseconds: UInt64?

    init(
        initialStorage: [String: Data] = [:],
        delayNanoseconds: UInt64? = nil
    ) {
        self.storage = initialStorage
        self.delayNanoseconds = delayNanoseconds
    }

    func data(key: String) async -> Data? {
        dataCalls += 1
        
        if let delayNanoseconds {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        
        return storage[key]
    }

    func insert(_ data: Data, key: String, ttl: TimeInterval?) async throws {
        storage[key] = data
    }

    func removeData(key: String) async throws {
        removeCalls += 1
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
    
    func removeCallCount() -> Int {
        removeCalls
    }
}

private final class MockImageDecoder: ImageDecoderType, @unchecked Sendable {
    let image: UIImage
    private let lock = NSLock()
    private var _decodeCount = 0
    
    var decodeCount: Int {
        lock.withLock {
            _decodeCount
        }
    }

    init(image: UIImage) {
        self.image = image
    }

    func decode(
        _ data: Data,
        targetSize: CGSize?,
        scale: CGFloat
    ) throws -> UIImage {
        lock.withLock {
            _decodeCount += 1
        }
        return image
    }
}

private final class FailingOnceImageDecoder: ImageDecoderType, @unchecked Sendable {
    let image: UIImage
    private let lock = NSLock()
    private var shouldFail = true
    private var _decodeCount = 0
    
    var decodeCount: Int {
        lock.withLock {
            _decodeCount
        }
    }
    
    init(image: UIImage) {
        self.image = image
    }
    
    func decode(
        _ data: Data,
        targetSize: CGSize?,
        scale: CGFloat
    ) throws -> UIImage {
        try lock.withLock {
            _decodeCount += 1
            
            if shouldFail {
                shouldFail = false
                throw ImageDecoderError.invalidImageData
            }
            
            return image
        }
    }
}

private enum TestProcessorError: Error, Equatable {
    case failed
}

private struct FailingImageProcessor: ImageProcessor {
    let identifier = "failing"
    
    func process(_ image: UIImage) throws -> UIImage {
        throw TestProcessorError.failed
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
