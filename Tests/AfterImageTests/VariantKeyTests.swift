//
//  VariantKeyTests.swift
//  AfterImageTests
//
//  Created by 김동현 on 4/14/26.
//

import Foundation
import CoreGraphics
import Testing
@testable import AfterImage

struct VariantKeyTests {
    
    @Test("동일한 Variant 구성은 동일한 cacheKey를 생성한다")
    func sameVariantProducesSameCacheKey() {
        // Given
        let lhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 200),
            scale: 2.0,
            processorIdentifiers: ["resize", "round"],
            schemaVersion: "v1"
        )
        
        let rhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 200),
            scale: 2.0,
            processorIdentifiers: ["resize", "round"],
            schemaVersion: "v1"
        )
        
        // When
        let lhsKey = lhs.cacheKey
        let rhsKey = rhs.cacheKey
        
        // Then
        #expect(lhsKey == rhsKey)
    }
    
    @Test("URL이 다르면 다른 cacheKey를 생성한다")
    func differentURLProducesDifferentCacheKey() {
        // Given
        let lhs = VariantKey(
            requestURL: URL(string: "https://example.com/image-a.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["resize"]
        )
        
        let rhs = VariantKey(
            requestURL: URL(string: "https://example.com/image-b.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["resize"]
        )
        
        // When / Then
        #expect(lhs.cacheKey != rhs.cacheKey)
    }
    
    @Test("targetSize가 다르면 다른 cacheKey를 생성한다")
    func differentTargetSizeProducesDifferentCacheKey() {
        // Given
        let lhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["resize"]
        )
        
        let rhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 200, height: 200),
            scale: 2.0,
            processorIdentifiers: ["resize"]
        )
        
        // When / Then
        #expect(lhs.cacheKey != rhs.cacheKey)
    }
    
    @Test("scale이 다르면 다른 cacheKey를 생성한다")
    func differentScaleProducesDifferentCacheKey() {
        // Given
        let lhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["resize"]
        )
        
        let rhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 3.0,
            processorIdentifiers: ["resize"]
        )
        
        // When / Then
        #expect(lhs.cacheKey != rhs.cacheKey)
    }
    
    @Test("processorIdentifiers가 다르면 다른 cacheKey를 생성한다")
    func differentProcessorsProduceDifferentCacheKey() {
        // Given
        let lhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["resize", "round"]
        )
        
        let rhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["resize", "blur"]
        )
        
        // When / Then
        #expect(lhs.cacheKey != rhs.cacheKey)
    }
    
    @Test("schemaVersion이 다르면 다른 cacheKey를 생성한다")
    func differentSchemaVersionProducesDifferentCacheKey() {
        // Given
        let lhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["resize"],
            schemaVersion: "v1"
        )
        
        let rhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["resize"],
            schemaVersion: "v2"
        )
        
        // When / Then
        #expect(lhs.cacheKey != rhs.cacheKey)
    }
    
    @Test("targetSize가 nil이면 nil 표현을 포함한 고정된 키를 생성한다")
    func nilTargetSizeProducesStableKey() {
        // Given
        let lhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: nil,
            scale: 2.0,
            processorIdentifiers: ["resize"]
        )
        
        let rhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: nil,
            scale: 2.0,
            processorIdentifiers: ["resize"]
        )
        
        // When / Then
        #expect(lhs.cacheKey == rhs.cacheKey)
    }
    
    @Test("processorIdentifiers가 비어 있으면 동일 조건에서 동일한 cacheKey를 생성한다")
    func emptyProcessorsProduceStableKey() {
        // Given
        let lhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 80, height: 80),
            scale: 2.0,
            processorIdentifiers: []
        )
        
        let rhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 80, height: 80),
            scale: 2.0,
            processorIdentifiers: []
        )
        
        // When / Then
        #expect(lhs.cacheKey == rhs.cacheKey)
    }
    
    @Test("processorIdentifiers의 순서가 다르면 다른 cacheKey를 생성한다")
    func processorOrderAffectsCacheKey() {
        // Given
        let lhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["resize", "round"]
        )

        let rhs = VariantKey(
            requestURL: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processorIdentifiers: ["round", "resize"]
        )

        // When / Then
        #expect(lhs.cacheKey != rhs.cacheKey)
    }

    @Test("ImageRequest 기반 init에서 schemaVersion이 다르면 다른 cacheKey를 생성한다")
    func requestBasedInitRespectsSchemaVersion() {
        // Given
        let request1 = ImageRequest(
            url: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processors: []
        )

        let request2 = ImageRequest(
            url: URL(string: "https://example.com/image.png")!,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2.0,
            processors: []
        )

        let lhs = VariantKey(request: request1, schemaVersion: "v1")
        let rhs = VariantKey(request: request2, schemaVersion: "v2")

        // When / Then
        #expect(lhs.cacheKey != rhs.cacheKey)
    }
}