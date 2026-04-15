// The Swift Programming Language
// https://docs.swift.org/swift-book

/**
 https://velog.io/@o_joon_/Swift-Image-caching이미지-캐싱
 https://dev-voo.tistory.com/49
 https://heidi-dev.tistory.com/54
 https://trumanfromkorea.tistory.com/84 // 다운샘플링
 https://xerathcoder.tistory.com/279
 https://applecider2020.tistory.com/54 // sha256
 https://kimsangjunzzang.tistory.com/104
 https://ios-development.tistory.com/715
 
 https://ios-adventure-with-aphelios.tistory.com/30
 https://velog.io/@o_joon_/Swift-Image-caching이미지-캐싱
 https://codeisfuture.tistory.com/121

 
 prefetch
 https://ios-development.tistory.com/715
 
 동시성
 https://ios-adventure-with-aphelios.tistory.com/30
 
 캐싱플로우
 https://ios-adventure-with-aphelios.tistory.com/30
 
 얕은복사
 https://heidi-dev.tistory.com/54
 
 제라스
 https://xerathcoder.tistory.com/279
 
 https://codeisfuture.tistory.com/121
 */

/*
 https://velog.io/@o_joon_/Swift-Image-caching이미지-캐싱
 https://dev-voo.tistory.com/49
 https://babbab2.tistory.com/164 // 클로저
 https://kimsangjunzzang.tistory.com/104
 
 2-Layer Cache 전략
 Memory Cache(1차 방어선) : 가장 빠른 RAM에서 먼저 찾아본다.
 Disk Cache(2차 방어선) : Memory에 없으면 디스크에서 찾아봅니다. 찾았다면, 다음 접근을 위해 Memory에도 올려놓습니다.
 Network(최후) : 둘다 없으면, 네트워크에서 다운로드하여 Memory와 Disk 양쪽에 모두 저장합니다.
 
 NSCache
 - 리소스가 부족할 때 제거될 수 있으며 임시로 키-값 쌍을 사용하는 변경 가능한 컬렉션
 - 캐시가 메모리를 너무 많이 사용하지 않도록 자동으로 캐시 제거
 
 let cache = NSCache<NSString, UIImage>()
 - String이 아닌 NSString이 쓰이는 이유
 - NSCache가 Objective-C 기반 클래스(NSObject)이기 때문에 swift와 objectivec의 호완성을 위해 NSString을 쓴다
 
 클로저
 - 기본적으로 파라미터로 받는 "클로저"는 함수 흐름을 탈출하지 못한다
 - escaping 키워드를 붙여주면 이 클로저는 함수 실행 흐름에 상관 없이 실행되는 클로저라고 알려주는 것이다
 - 함수 파라미터의 클로저가 옵셔널 타입인 경우 자동으로 escaping으로 동작한다
 */

import UIKit

/// AfterImage의 public entry point입니다.
///
/// 외부 사용자는 `ImagePipeline`, `MemoryCache`, `DiskCache`, `DataLoader`, `ImageDecoder`를
/// 직접 조립하지 않고 이 타입을 통해 이미지를 요청할 수 있습니다.
public final class AfterImage {
    
    /// 기본 설정으로 구성된 공유 인스턴스입니다.
    public static let shared = AfterImage()
    
    private let pipeline: any ImagePipelineType
    
    /// 테스트나 커스텀 구성을 위해 파이프라인을 직접 주입합니다.
    ///
    /// - Parameter pipeline: 이미지 요청을 처리할 파이프라인입니다.
    public init(pipeline: any ImagePipelineType) {
        self.pipeline = pipeline
    }
    
    /// configuration을 기반으로 기본 파이프라인을 구성합니다.
    ///
    /// - Parameter configuration: 메모리/디스크 캐시 설정입니다.
    public convenience init(configuration: AfterImageConfiguration) {
        let memoryCache = LRUMemoryCache<CacheKey, UIImage>(
            configuration: configuration.memoryCacheConfiguration
        )
        
        let diskCache = DiskCache(
            configuration: configuration.diskCacheConfiguration
        )
        
        
        let pipeline = ImagePipeline(
            memoryCache: memoryCache,
            diskCache: diskCache,
            dataLoader: URLSessionDataLoader(),
            imageDecoder: ImageDecoder()
        )
        
        self.init(pipeline: pipeline)
    }
    
    /// 기본 configuration으로 AfterImage를 생성합니다.
    public convenience init() {
        self.init(configuration: .default)
    }
    
    /// `ImageRequest`를 기반으로 이미지를 로드합니다.
    ///
    /// - Parameter request: 이미지 로딩 요청입니다.
    /// - Returns: 디코딩과 후처리가 완료된 이미지입니다.
    public func image(for request: ImageRequest) async throws -> UIImage {
        try await pipeline.loadImage(request)
    }
    
    /// URL 기반의 간단한 이미지 로딩 API입니다.
    ///
    /// 내부적으로 `ImageRequest`를 만들어 파이프라인에 전달합니다.
    public func image(
        url: URL,
        targetSize: CGSize? = nil,
        scale: CGFloat? = nil,
        cachePolicy: CachePolicy = .useCache,
        processors: [any ImageProcessor] = []
    ) async throws -> UIImage {
        let resolvedScale = if let scale {
            scale
        } else {
            await MainActor.run {
                UIScreen.main.scale
            }
        }
        
        let request = ImageRequest(
            url: url,
            targetSize: targetSize,
            scale: resolvedScale,
            cachePolicy: cachePolicy,
            processors: processors
        )
        
        return try await image(for: request)
    }
}
