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
/// 2. 디스크 캐시 조회
/// 3. 네트워크 요청
/// 4. 디코딩 및 후처리(processor 적용)
/// 5. 캐시 저장
///
/// 또한 동일한 `CacheKey`에 대한 동시 요청이 발생하면, 이미 진행 중인 작업을
/// `inFlightTasks`에서 재사용하여 중복 네트워크 요청을 방지합니다.
///
/// ## 동작 개요
/// - 메모리 캐시에 값이 있으면 즉시 반환합니다.
/// - 메모리에 없으면 디스크 캐시를 조회합니다.
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
    /// 같은 `CacheKey`에 대해 동시에 여러 요청이 들어오면 새 작업을 만들지 않고,
    /// 이미 진행 중인 `Task`를 재사용하여 중복 네트워크 요청과 중복 디코딩을 방지합니다.
    ///
    /// 예를 들어 동일한 URL/variant에 대한 요청이 거의 동시에 3번 들어와도
    /// 실제 네트워크 요청은 1번만 수행되고, 나머지 호출자는 같은 결과를 함께 기다립니다.
    private var inFlightTasks: [CacheKey: Task<UIImage, Error>] = [:]
    
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
    /// 동일한 `CacheKey`에 대한 요청이 이미 진행 중이라면 해당 작업을 재사용합니다.
    ///
    /// - Parameter request: 로드할 이미지 요청 정보입니다.
    /// - Returns: 디코딩 및 후처리가 완료된 최종 이미지입니다.
    /// - Throws: 캐시 miss, 디코딩 실패, 네트워크 실패, processor 실패 등의 에러를 던질 수 있습니다.
    public func loadImage(_ request: ImageRequest) async throws -> UIImage {
            let cacheKey = VariantKey(request: request).cacheKey
            
            // 1. 메모리 캐시 조회
            // 가장 빠른 경로이므로, 정책이 허용한다면 우선적으로 확인합니다.
            if request.cachePolicy.allowsMemoryRead,
               let image = memoryCache.value(key: cacheKey) {
                return image
            }
            
            // 2. 디스크 캐시 조회
            // 메모리에 없고 디스크 읽기가 허용된 경우, 디스크에 저장된 원본 데이터를 확인합니다.
            if request.cachePolicy.allowsDiskRead,
               let cachedData = await diskCache.data(key: cacheKey.rawValue) {
                do {
                    // 디스크에 저장된 원본 데이터를 decode하고,
                    // 요청에 포함된 processor들을 순서대로 적용합니다.
                    let image = try decodeAndProcess(cachedData, request: request)
                    
                    // 디스크에서 성공적으로 복원한 이미지는 이후 더 빠르게 접근할 수 있도록
                    // 메모리 캐시에 다시 올려둡니다.
                    if request.cachePolicy.allowsMemoryWrite {
                        memoryCache.insertImage(image, key: cacheKey)
                    }
                    
                    return image
                } catch {
                    // 디스크 데이터는 존재하지만 decode/process 단계에서 실패한 경우입니다.
                    // 손상된 데이터이거나, 현재 디코더/processor로 처리할 수 없는 데이터일 수 있습니다.
                    
                    if request.cachePolicy.allowsNetworkLoad {
                        // 네트워크 fallback이 허용된다면,
                        // 손상된 디스크 엔트리를 제거한 뒤 아래 네트워크 경로로 계속 진행합니다.
                        try? await diskCache.removeData(key: cacheKey.rawValue)
                    } else {
                        // 네트워크 요청이 허용되지 않는 정책이라면
                        // 더 이상 fallback 경로가 없으므로 에러를 그대로 전달합니다.
                        throw error
                    }
                }
            }
            
            // 3. 네트워크 요청 가능 여부 확인
            // 캐시에서 결과를 얻지 못했고, 네트워크도 허용되지 않으면 cache miss입니다.
            guard request.cachePolicy.allowsNetworkLoad else {
                throw ImagePipelineError.cacheMiss
            }
            
            // 4. in-flight deduplication
            // 같은 키의 요청이 이미 진행 중이라면 새 작업을 만들지 않고 기존 작업 결과를 기다립니다.
            if let inFlightTask = inFlightTasks[cacheKey] {
                return try await inFlightTask.value
            }
            
            // 5. 새로운 네트워크 로딩 작업 생성
            let task = Task {
                try await loadFromNetworkAndStoreCaches(
                    request,
                    cacheKey: cacheKey
                )
            }
            
            // 진행 중 작업 목록에 먼저 등록해 이후 동일 요청이 재사용할 수 있게 합니다.
            inFlightTasks[cacheKey] = task
            
            do {
                let image = try await task.value
                
                // 작업이 정상적으로 끝났으면 in-flight 목록에서 제거합니다.
                inFlightTasks[cacheKey] = nil
                return image
            } catch {
                // 실패한 작업도 반드시 목록에서 제거해 다음 요청이 새로 시작될 수 있게 합니다.
                inFlightTasks[cacheKey] = nil
                throw error
            }
        }
}

private extension ImagePipeline {
    
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
        // 원본 데이터를 요청 크기/배율 정보에 맞게 UIImage로 변환합니다.
        var image = try imageDecoder.decode(
            data,
            targetSize: request.targetSize,
            scale: request.scale
        )
        
        // 요청에 포함된 processor를 순서대로 적용합니다.
        // processor 순서는 최종 결과에 영향을 줄 수 있으므로 입력 순서를 유지합니다.
        for processor in request.processors {
            image = try processor.process(image)
        }
        
        return image
    }
}
