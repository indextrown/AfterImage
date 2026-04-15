//
//  ImagePipeline.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import UIKit

/// 이미지 요청을 메모리 캐시, 디스크 캐시, 네트워크, 디코더와 연결하는 중심 파이프라인입니다.
///
/// 1차 구현에서는 in-flight dedupe 없이 기본 캐시 흐름만 처리합니다.
public actor ImagePipeline: ImagePipelineType {
    
    private let memoryCache: LRUMemoryCache<CacheKey, UIImage>
    private let diskCache: any DiskCacheType
    private let dataLoader: any DataLoaderType
    private let imageDecoder: any ImageDecoderType
    
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
    
    public func loadImage(_ request: ImageRequest) async throws -> UIImage {
        let cacheKey = VariantKey(request: request).cacheKey
        
        // 1. Memory Cache 조회
        // 가장 빠른 경로이므로 허용되어 있다면 우선적으로 조회합니다.
        if request.cachePolicy.allowsMemoryRead,
           let image = memoryCache.value(key: cacheKey) {
            return image
        }
        
        // 2. Disk Cache 조회
        // 메모리에 없고, 디스크 읽기가 허용된 경우 디스크 캐시를 확인합니다.
        if request.cachePolicy.allowsDiskRead,
           let cachedData = await diskCache.data(key: cacheKey.rawValue) {
            do {
                // 디스크에 저장된 데이터를 decode + processor 적용
                let image = try decodeAndProcess(cachedData, request: request)
                
                // 디스크 → 메모리 캐시 승격 (read-through caching)
                if request.cachePolicy.allowsMemoryWrite {
                    memoryCache.insertImage(image, key: cacheKey)
                }
                
                return image
            } catch {
                // ⚠️ 디스크 데이터는 존재하지만 decode/process 실패
                // → 데이터가 손상되었거나 현재 decode 불가능한 상태일 수 있음
                
                if request.cachePolicy.allowsNetworkLoad {
                    // 네트워크 요청이 허용된 경우:
                    // 손상된 디스크 엔트리를 제거하고 네트워크 fallback 진행
                    try? await diskCache.removeData(key: cacheKey.rawValue)
                    
                    // 여기서 return하지 않고 아래 네트워크 경로로 계속 진행
                } else {
                    // 네트워크 요청이 불가능한 정책이라면
                    // fallback이 없으므로 그대로 에러 전달
                    throw error
                }
            }
        }
        
        // 3. Network 요청
        // 캐시에서 가져오지 못했고, 네트워크도 불가능하면 실패
        guard request.cachePolicy.allowsNetworkLoad else {
            throw ImagePipelineError.cacheMiss
        }
        
        // 네트워크에서 원본 데이터 로드
        let data = try await dataLoader.data(url: request.url)
        
        // decode + processor 적용
        let image = try decodeAndProcess(data, request: request)
        
        // 네트워크 → 디스크 캐시 저장 (write-through)
        if request.cachePolicy.allowsDiskWrite {
            try await diskCache.insert(
                data,
                key: cacheKey.rawValue,
                ttl: nil
            )
        }
        
        // 네트워크 → 메모리 캐시 저장
        if request.cachePolicy.allowsMemoryWrite {
            memoryCache.insertImage(image, key: cacheKey)
        }
        
        return image
    }
}

private extension ImagePipeline {
    func decodeAndProcess(
        _ data: Data,
        request: ImageRequest
    ) throws -> UIImage {
        var image = try imageDecoder.decode(
            data,
            targetSize: request.targetSize,
            scale: request.scale
        )
        
        for processor in request.processors {
            image = try processor.process(image)
        }
        
        return image
    }
}
