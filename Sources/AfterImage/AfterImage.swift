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
/// 직접 조립하지 않고 이 타입을 통해 이미지를 요청할 수 있습니다.(Facade)
public final class AfterImage: @unchecked Sendable {
    
    /// 기본 설정으로 구성된 공유 인스턴스입니다.
    public static let shared = AfterImage()
    
    /// 공유 인스턴스의 mutable 상태를 보호하는 잠금입니다.
    ///
    /// `configure(_:)`가 pipeline을 교체하는 순간과 `image(for:)`가 현재 pipeline을
    /// 읽는 순간이 동시에 발생할 수 있으므로, 짧은 critical section만 보호합니다.
    private let lock = NSLock()
    
    /// 실제 이미지 로딩을 수행하는 파이프라인입니다.
    ///
    /// 기본값은 `.default` configuration으로 만들어지며, 앱 시작 시 `configure(_:)`를
    /// 호출하면 새로운 설정을 반영한 파이프라인으로 교체됩니다.
    private var pipeline: any ImagePipelineType
    
    /// 공유 인스턴스가 이미 명시적으로 설정되었는지 나타냅니다.
    ///
    /// 이미지 로딩 중 설정이 다시 바뀌면 기존 in-flight 작업과 새 파이프라인이
    /// 분리될 수 있으므로, `AfterImage.shared`는 앱 시작 시 한 번만 설정하는 것을 권장합니다.
    private var isConfigured = false
    
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
        self.init(pipeline: Self.makePipeline(configuration: configuration))
    }

    /// 기본 configuration으로 AfterImage를 생성합니다.
    public convenience init() {
        self.init(configuration: .default)
    }
    
    /// 공유 인스턴스가 사용할 기본 파이프라인 설정을 앱 시작 시 한 번 지정합니다.
    ///
    /// Kingfisher의 `ImageCache.default` 설정처럼, 앱의 `init`에서 한 번 호출한 뒤
    /// 화면에서는 `AfterImage.shared`를 직접 사용하도록 하기 위한 API입니다.
    ///
    /// - Important:
    ///   이미지 로딩이 진행 중인 시점에 설정을 다시 바꾸면 기존 in-flight 작업과
    ///   새 파이프라인이 분리될 수 있으므로, 앱 시작 시 한 번만 호출하는 것을 권장합니다.
    public func configure(_ configuration: AfterImageConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isConfigured else {
            assertionFailure("AfterImage.shared should be configured once at app launch.")
            return
        }
        
        pipeline = Self.makePipeline(configuration: configuration)
        isConfigured = true
    }
    
    /// `ImageRequest`를 기반으로 이미지를 로드합니다.
    ///
    /// - Parameter request: 이미지 로딩 요청입니다.
    /// - Returns: 디코딩과 후처리가 완료된 이미지입니다.
    public func image(for request: ImageRequest) async throws -> UIImage {
        let pipeline = currentPipeline()
        return try await pipeline.loadImage(request)
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
    
    /// 현재 shared 파이프라인이 들고 있는 메모리 캐시와 디스크 캐시를 모두 비웁니다.
    ///
    /// 앱에서 설정한 `AfterImage.shared.configure(_:)`의 캐시 인스턴스를 대상으로 동작합니다.
    /// 캐시 삭제 후 기존 화면을 다시 로드하려면 UI 쪽에서 reload trigger를 갱신해야 합니다.
    public func clearCache() async throws {
        let pipeline = currentPipeline()
        try await pipeline.clearCache()
    }
    
    /// 현재 사용할 파이프라인을 안전하게 반환합니다.
    ///
    /// 파이프라인 참조만 잠금 안에서 가져오고, 실제 이미지 로딩은 잠금 밖에서 수행합니다.
    /// 이렇게 해야 네트워크, 디스크 IO, 디코딩 작업이 전역 lock을 오래 점유하지 않습니다.
    private func currentPipeline() -> any ImagePipelineType {
        lock.lock()
        defer { lock.unlock() }
        
        return pipeline
    }
    
    /// configuration을 기반으로 AfterImage 기본 파이프라인을 조립합니다.
    ///
    /// 이 메서드는 `AfterImage`의 public facade가 내부 구현체 생성 방식을 숨기기 위해 사용합니다.
    /// 외부 사용자는 메모리 캐시, 디스크 캐시, 데이터 로더, 디코더를 직접 조립하지 않아도 됩니다.
    private static func makePipeline(
        configuration: AfterImageConfiguration
    ) -> any ImagePipelineType {
        let memoryCache = LRUMemoryCache<CacheKey, UIImage>(
            configuration: configuration.memoryCacheConfiguration
        )
        
        let diskCache = DiskCache(
            configuration: configuration.diskCacheConfiguration
        )
        
        return ImagePipeline(
            memoryCache: memoryCache,
            diskCache: diskCache,
            dataLoader: URLSessionDataLoader(),
            imageDecoder: ImageDecoder()
        )
    }
}
