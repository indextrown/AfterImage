//
//  ImageRequest.swift
//  AfterImage
//
//  Created by 김동현 on 4/14/26.
//

import Foundation

/// AfterImage의 이미지 로딩 요청 단위입니다.
///
/// URL 하나만으로 이미지를 식별하지 않고, 표시 크기와 후처리 정보까지 포함해
/// 캐시 키와 파이프라인 동작의 기준으로 사용합니다.
public struct ImageRequest: Sendable {
    public let url: URL
    public let targetSize: CGSize?
    public let scale: CGFloat
    public let cachePolicy: CachePolicy
    public let processors: [any ImageProcessor]
    
    public init(
        url: URL,
        targetSize: CGSize? = nil,
        scale: CGFloat = 1,
        cachePolicy: CachePolicy = .useCache,
        processors: [any ImageProcessor] = []
    ) {
        precondition(
            scale.isFinite && scale > 0,
            "ImageRequest.scale must be finite and > 0"
        )
        if let targetSize {
            precondition(
                targetSize.width.isFinite && targetSize.height.isFinite &&
                targetSize.width > 0 && targetSize.height > 0,
                "ImageRequest.targetSize must have finite, positive width/height"
            )
        }
        self.url = url
        self.targetSize = targetSize
        self.scale = scale
        self.cachePolicy = cachePolicy
        self.processors = processors
    }
}
