//
//  ImagePipeline.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import UIKit

/// 이미지 요청을 메모리 캐시, 디스크 캐시, 네트워크, 디코더와 연결하는 중심 파이프라인입니다.
///
/// `ImagePipeline`은 하나의 이미지 요청에 대해 다음 순서로 결과를 조회합니다.
///
/// 1. 메모리 캐시 조회
/// 2. 동일 `CacheKey + CachePolicy`의 진행 중 작업 재사용
/// 3. 디스크 캐시 조회
/// 4. 네트워크 요청
/// 5. 디코딩 및 후처리(processor 적용)
/// 6. 캐시 저장
///
/// 또한 메모리 캐시 miss 이후 동일한 `CacheKey`와 `CachePolicy` 조합의 동시 요청이
/// 발생하면, 이미 진행 중인 작업을 `inFlightTasks`에서 재사용합니다.
/// 이를 통해 중복 디스크 조회, 중복 디코딩, 중복 네트워크 요청을 줄입니다.
///
/// ## 동작 개요
/// - 메모리 캐시에 값이 있으면 즉시 반환합니다.
/// - 메모리에 없고 같은 `CacheKey + CachePolicy` 작업이 진행 중이면 그 결과를 기다립니다.
/// - 진행 중인 작업이 없으면 디스크 캐시를 조회합니다.
/// - 디스크 캐시 데이터가 존재하면 decode 및 processor 적용 후 반환합니다.
/// - 디스크 데이터가 손상되어 decode에 실패하면, 네트워크 허용 여부에 따라
///   디스크 엔트리를 제거하고 네트워크로 fallback 하거나 에러를 그대로 전달합니다.
/// - 캐시에도 없고 네트워크도 허용되지 않으면 `ImagePipelineError.cacheMiss`를 던집니다.
///
/// ## 참고
/// - 이 타입은 `actor`로 선언되어, 파이프라인 내부 상태(`inFlightTasks`)를
///   안전하게 직렬화하여 관리합니다.
public actor ImagePipeline: ImagePipelineType {
    
    /// 디코딩된 이미지를 메모리에 저장하는 LRU 캐시입니다.
    ///
    /// 가장 빠른 조회 경로이며, 캐시 정책이 허용하는 경우 가장 먼저 조회됩니다.
    private let memoryCache: LRUMemoryCache<CacheKey, UIImage>
    
    /// 원본 이미지 데이터를 저장하는 디스크 캐시입니다.
    ///
    /// 메모리 캐시에 값이 없을 때 조회하며, 네트워크에서 받은 원본 데이터도
    /// 필요 시 여기에 저장됩니다.
    private let diskCache: any DiskCacheType
    
    /// URL로부터 원본 데이터를 로드하는 네트워크 로더입니다.
    private let dataLoader: any DataLoaderType
    
    /// 원본 데이터를 `UIImage`로 디코딩하는 디코더입니다.
    ///
    /// 필요 시 target size와 scale 정보를 함께 사용합니다.
    private let imageDecoder: any ImageDecoderType
    
    
    /// 현재 진행 중인 이미지 로딩 작업 목록입니다.
    ///
    /// 같은 `CacheKey`와 `CachePolicy` 조합에 대해 동시에 여러 요청이 들어오면
    /// 새 작업을 만들지 않고, 이미 진행 중인 `Task`를 재사용합니다.
    ///
    /// `CachePolicy`를 키에 포함하는 이유는 같은 이미지 variant라도 네트워크 fallback
    /// 가능 여부가 다를 수 있기 때문입니다. 예를 들어 cache-only 요청이 네트워크 허용
    /// 요청과 같은 작업을 공유하면 정책 의도와 다른 결과가 나올 수 있습니다.
    private var inFlightTasks: [InFlightKey: Task<UIImage, Error>] = [:]
    
    /// 새로운 이미지 파이프라인을 생성합니다.
    ///
    /// - Parameters:
    ///   - memoryCache: 디코딩된 이미지를 저장할 메모리 캐시입니다.
    ///   - diskCache: 원본 데이터를 저장할 디스크 캐시입니다.
    ///   - dataLoader: 네트워크에서 데이터를 가져오는 로더입니다.
    ///   - imageDecoder: 원본 데이터를 이미지로 변환하는 디코더입니다.
    public init(
        memoryCache: LRUMemoryCache<CacheKey, UIImage>,
        diskCache: any DiskCacheType,
        dataLoader: any DataLoaderType,
        imageDecoder: any ImageDecoderType
    ) {
        self.memoryCache = memoryCache
        self.diskCache = diskCache
        self.dataLoader = dataLoader
        self.imageDecoder = imageDecoder
    }
    
    /// 주어진 이미지 요청을 처리하여 최종 이미지를 반환합니다.
    ///
    /// 이 메서드는 캐시 정책에 따라 메모리 캐시, 디스크 캐시, 네트워크 순으로 조회하며,
    /// 필요한 경우 디코딩 및 processor 적용을 수행합니다.
    ///
    /// 동일한 `CacheKey + CachePolicy` 요청이 이미 진행 중이라면 해당 작업을 재사용합니다.
    ///
    /// - Parameter request: 로드할 이미지 요청 정보입니다.
    /// - Returns: 디코딩 및 후처리가 완료된 최종 이미지입니다.
    /// - Throws: 캐시 miss, 디코딩 실패, 네트워크 실패, processor 실패 등의 에러를 던질 수 있습니다.
    public func loadImage(_ request: ImageRequest) async throws -> UIImage {
            let cacheKey = VariantKey(request: request).cacheKey
            let inFlightKey = InFlightKey(
                cacheKey: cacheKey,
                cachePolicy: request.cachePolicy
            )
            
            // 1. 메모리 캐시 조회
            // 가장 빠른 경로이므로, 정책이 허용한다면 우선적으로 확인합니다.
            if request.cachePolicy.allowsMemoryRead,
               let image = memoryCache.value(key: cacheKey) {
                return image
            }
            
            // 2. in-flight deduplication
            // 같은 키와 같은 캐시 정책의 요청이 이미 진행 중이라면 새 작업을 만들지 않고 기존 작업 결과를 기다립니다.
            if let inFlightTask = inFlightTasks[inFlightKey] {
                return try await inFlightTask.value
            }
            
            // 3. 메모리 miss 이후의 디스크/네트워크 경로를 하나의 작업으로 묶습니다.
            let task = Task {
                do {
                    let image = try await loadFromDiskOrNetworkAndStoreCaches(
                        request,
                        cacheKey: cacheKey
                    )
                    
                    removeInFlightTask(for: inFlightKey)
                    return image
                } catch {
                    removeInFlightTask(for: inFlightKey)
                    throw error
                }
            }
            
            // 진행 중 작업 목록에 먼저 등록해 이후 동일 요청이 재사용할 수 있게 합니다.
            inFlightTasks[inFlightKey] = task
            return try await task.value
        }
    
    /// 현재 파이프라인의 메모리 캐시와 디스크 캐시를 모두 비웁니다.
    ///
    /// 진행 중인 요청은 취소하지 않습니다. 삭제 이후 새로 들어오는 요청은
    /// 비워진 캐시 상태에서 다시 메모리, 디스크, 네트워크 순서로 로드합니다.
    public func clearCache() async throws {
        memoryCache.removeAll()
        try await diskCache.removeAll()
    }
    
    /// 공유 `Task`가 실제로 완료된 뒤 in-flight 목록에서 제거합니다.
    ///
    /// 대기 중인 호출자가 취소되더라도 공유 작업 자체가 아직 실행 중이라면
    /// in-flight 항목이 먼저 제거되지 않도록 cleanup 책임을 task 실행 흐름에 둡니다.
    private func removeInFlightTask(for inFlightKey: InFlightKey) {
        inFlightTasks[inFlightKey] = nil
    }
}

private extension ImagePipeline {
    
    struct InFlightKey: Hashable {
        /// 같은 이미지 variant라도 캐시 정책이 다르면 fallback 가능 여부가 달라지므로
        /// 별도 작업으로 취급합니다.
        let cacheKey: CacheKey
        let cachePolicy: CachePolicy
    }
    
    /// 메모리 캐시 miss 이후의 디스크 캐시 조회와 네트워크 fallback을 처리합니다.
    ///
    /// 이 메서드 전체가 in-flight task에 들어가므로, 동일 `CacheKey + CachePolicy`
    /// 요청의 중복 디스크 조회, 중복 디코딩, 중복 네트워크 요청을 함께 줄일 수 있습니다.
    func loadFromDiskOrNetworkAndStoreCaches(
        _ request: ImageRequest,
        cacheKey: CacheKey
    ) async throws -> UIImage {
        // 디스크 캐시 조회
        if request.cachePolicy.allowsDiskRead,
           let cachedData = await diskCache.data(key: cacheKey.rawValue) {
            let decodedImage: UIImage?
            
            do {
                decodedImage = try decode(cachedData, request: request)
            } catch {
                if request.cachePolicy.allowsNetworkLoad {
                    try? await diskCache.removeData(key: cacheKey.rawValue)
                    decodedImage = nil
                } else {
                    throw error
                }
            }
            
            if let decodedImage {
                let image = try process(decodedImage, request: request)
                
                if request.cachePolicy.allowsMemoryWrite {
                    memoryCache.insertImage(image, key: cacheKey)
                }
                
                return image
            }
        }
        
        guard request.cachePolicy.allowsNetworkLoad else {
            throw ImagePipelineError.cacheMiss
        }
        
        return try await loadFromNetworkAndStoreCaches(
            request,
            cacheKey: cacheKey
        )
    }
    
    /// 네트워크에서 원본 데이터를 로드하고, 디코딩 및 후처리 후 캐시에 저장합니다.
    ///
    /// 이 메서드는 캐시 miss 이후 실제 네트워크 경로를 담당합니다.
    ///
    /// - Parameters:
    ///   - request: 이미지 요청 정보입니다.
    ///   - cacheKey: 현재 요청의 variant를 반영한 캐시 키입니다.
    /// - Returns: 디코딩 및 후처리가 완료된 최종 이미지입니다.
    /// - Throws: 데이터 로드 실패, 디코딩 실패, 디스크 저장 실패, processor 실패 등의 에러를 던질 수 있습니다.
    func loadFromNetworkAndStoreCaches(
        _ request: ImageRequest,
        cacheKey: CacheKey
    ) async throws -> UIImage {
        // 네트워크에서 원본 데이터를 가져옵니다.
        let data = try await dataLoader.data(url: request.url)
        
        // 가져온 원본 데이터를 디코딩하고 processor들을 적용해 최종 이미지를 만듭니다.
        let image = try decodeAndProcess(data, request: request)
        
        // 원본 데이터는 필요 시 디스크 캐시에 저장합니다.
        // 디스크 캐시는 보통 재디코딩 가능한 원본 바이트를 보관하는 용도로 사용합니다.
        if request.cachePolicy.allowsDiskWrite {
            try await diskCache.insert(
                data,
                key: cacheKey.rawValue,
                ttl: nil
            )
        }
        
        // 최종 이미지는 빠른 재사용을 위해 메모리 캐시에 저장합니다.
        if request.cachePolicy.allowsMemoryWrite {
            memoryCache.insertImage(image, key: cacheKey)
        }
        
        return image
    }
    
    /// 원본 데이터를 이미지로 디코딩하고, 요청에 포함된 processor를 순서대로 적용합니다.
    ///
    /// - Parameters:
    ///   - data: 디코딩할 원본 이미지 데이터입니다.
    ///   - request: target size, scale, processors 정보를 포함한 요청입니다.
    /// - Returns: 디코딩 및 후처리가 완료된 최종 이미지입니다.
    /// - Throws: 디코딩 실패 또는 processor 처리 실패 시 에러를 던집니다.
    func decodeAndProcess(
        _ data: Data,
        request: ImageRequest
    ) throws -> UIImage {
        let decodedImage = try decode(data, request: request)
        return try process(decodedImage, request: request)
    }
    
    /// 원본 데이터를 요청 크기/배율 정보에 맞게 `UIImage`로 변환합니다.
    func decode(
        _ data: Data,
        request: ImageRequest
    ) throws -> UIImage {
        try imageDecoder.decode(
            data,
            targetSize: request.targetSize,
            scale: request.scale
        )
    }
    
    /// 디코딩된 이미지에 요청의 processor를 순서대로 적용합니다.
    func process(
        _ decodedImage: UIImage,
        request: ImageRequest
    ) throws -> UIImage {
        var image = decodedImage
        
        // 요청에 포함된 processor를 순서대로 적용합니다.
        // processor 순서는 최종 결과에 영향을 줄 수 있으므로 입력 순서를 유지합니다.
        for processor in request.processors {
            image = try processor.process(image)
        }
        
        return image
    }
}
