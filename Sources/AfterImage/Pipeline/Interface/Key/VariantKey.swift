//
//  VariantKey.swift
//  AfterImage
//
//  Created by 김동현 on 4/14/26.
//

import Foundation

/// 요청의 Variant 정보를 기반으로 캐시 키를 생성하는 타입입니다.
///
/// 동일한 URL이라도 다음 요소들이 다르면 서로 다른 캐시 결과로 취급합니다:
/// - targetSize (리사이즈 여부)
/// - scale (디스플레이 스케일)
/// - processorIdentifiers (이미지 처리 파이프라인)
///
/// 이 값을 직렬화하여 메모리/디스크 캐시에서 공통으로 사용하는 키를 생성합니다.
public struct VariantKey: Hashable, Sendable {
    public let requestURL: URL
    public let targetSize: CGSize?
    public let scale: CGFloat
    public let processorIdentifiers: [String]
    public let schemaVersion: String
    
    /// 모든 Variant 구성 요소를 직접 받아 초기화합니다.
    ///
    /// - Parameters:
    ///   - requestURL: 이미지 요청 URL
    ///   - targetSize: 리사이즈 대상 크기 (nil이면 원본 유지)
    ///   - scale: 디스플레이 스케일 (예: 2.0, 3.0)
    ///   - processorIdentifiers: 적용된 processor 식별자 목록
    ///   - schemaVersion: 직렬화 포맷 버전 (기본값: "v1")
    public init(
        requestURL: URL,
        targetSize: CGSize?,
        scale: CGFloat,
        processorIdentifiers: [String],
        schemaVersion: String = "v1"
    ) {
        self.requestURL = requestURL
        self.targetSize = targetSize
        self.scale = scale
        self.processorIdentifiers = processorIdentifiers
        self.schemaVersion = schemaVersion
    }
    
    
    /// `ImageRequest` 기반으로 VariantKey를 생성하는 편의 이니셜라이저입니다.
    ///
    /// 내부적으로 지정 이니셜라이저(`init(requestURL:...)`)로 위임하여 초기화합니다.
    /// 구조체에서는 `convenience` 키워드가 없으며,
    /// `self.init(...)` 호출을 통해 **위임 이니셜라이저(delegating initializer)** 패턴을 사용합니다.
    ///
    /// - Parameters:
    ///   - request: 이미지 요청 정보
    ///   - schemaVersion: 직렬화 포맷 버전
    public init(
        request: ImageRequest,
        schemaVersion: String = "v1"
    ) {
        self.init(
            requestURL: request.url,
            targetSize: request.targetSize,
            scale: request.scale,
            processorIdentifiers: request.processors.map(\.identifier),
            schemaVersion: schemaVersion
        )
    }
    
    /// 직렬화된 값을 기반으로 `CacheKey`를 생성합니다.
    ///
    /// - Note:
    ///   - 메모리 캐시는 문자열 그대로 사용 가능
    ///   - 디스크 캐시는 별도의 해시 변환을 통해 파일명으로 사용하는 것이 안전합니다
    public var cacheKey: CacheKey {
        return CacheKey(rawValue: serializedValue)
    }
}

private extension VariantKey {
    
    /// CGFloat 값을 소수점 3자리로 고정하여 문자열로 변환합니다.
    ///
    /// - Note:
    ///   - 부동소수점 오차로 인해 동일 값이 다르게 직렬화되는 것을 방지합니다.
    func format(_ value: CGFloat) -> String {
        return String(format: "%.3f", Double(value))
    }
    
    /// targetSize를 문자열로 직렬화합니다.
    ///
    /// - nil → "nil"
    /// - 값 존재 → "width x height" 형태
    var serializedTargetSize: String {
        guard let targetSize else {
            return "nil"
        }
        
        return "\(format(targetSize.width))x\(format(targetSize.height))"
    }
    
    /// scale 값을 문자열로 직렬화합니다.
    var serializedScale: String {
        return format(scale)
    }
    
    /// processor 목록을 충돌 없이 문자열로 직렬화합니다.
    ///
    /// 각 identifier 앞에 UTF-8 바이트 길이를 함께 기록하여,
    /// identifier 내부에 구분자(`,`, `:` 등)가 포함되어 있어도
    /// 서로 다른 processor chain이 동일 문자열로 직렬화되지 않도록 합니다.
    ///
    /// 예:
    /// - [] → "count=0"
    /// - ["resize", "round"] → "count=2|6:resize,5:round"
    var serializedProcessors: String {
        guard processorIdentifiers.isEmpty == false else {
            return "count=0"
        }
        
        let serializedItems = processorIdentifiers
            .map { identifier in
                "\(identifier.utf8.count):\(identifier)"
            }
            .joined(separator: ",")
        
        return "count=\(processorIdentifiers.count)|\(serializedItems)"
    }
    
    /// VariantKey의 모든 요소를 하나의 문자열로 직렬화합니다.
    ///
    /// - Format:
    ///   schema=v1|url=...|targetSize=...|scale=...|processors=...
    ///
    /// - Note:
    ///   - 순서와 포맷이 바뀌면 기존 캐시와 호환되지 않으므로 schemaVersion으로 관리합니다.
    var serializedValue: String {
        [
            "schema=\(schemaVersion)",
            "url=\(requestURL.absoluteString)",
            "targetSize=\(serializedTargetSize)",
            "scale=\(serializedScale)",
            "processors=\(serializedProcessors)"
        ].joined(separator: "|")
    }
}
