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
        
        if request.cachePolicy.allowsMemoryRead,
           let image = memoryCache.value(key: cacheKey) {
            return image
        }
        
        if request.cachePolicy.allowsDiskRead,
           let data = await diskCache.data(key: cacheKey.rawValue) {
            let image = try decodeAndProcess(data, request: request)
            
            if request.cachePolicy.allowsMemoryWrite {
                memoryCache.insertImage(image, key: cacheKey)
            }
            
            return image
        }
        
        guard request.cachePolicy.allowsNetworkLoad else {
            throw ImagePipelineError.cacheMiss
        }
        
        let data = try await dataLoader.data(url: request.url)
        let image = try decodeAndProcess(data, request: request)
        
        if request.cachePolicy.allowsDiskWrite {
            try await diskCache.insert(
                data,
                key: cacheKey.rawValue,
                ttl: nil
            )
        }
        
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
