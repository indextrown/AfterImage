//
//  MemoryCacheTests.swift
//  AfterImageTests
//
//  Created by 김동현 on 4/12/26.
//

import Foundation
import UIKit
import Testing
@testable import AfterImage

struct MemoryCacheTests {
    
    @Test("값 저장 후 동일 키로 조회할 수 있다")
    func insertAndRetrieveValue() {
        // Given: 비어있는 캐시 생성
        let cache = LRUMemoryCache<String, String>(
            countLimit: 3,
            totalCostLimit: 100
        )
        
        // When: 값을 삽입
        cache.insert(value: "A", key: "a", cost: 10)
        
        // Then: 동일 키로 조회 시 값이 반환된다
        #expect(cache.value(key: "a") == "A")
    }
    
    @Test("존재하지 않는 키 조회 시 nil을 반환한다")
    func retrieveMissingValueReturnsNil() {
        // Given: 비어있는 캐시
        let cache = LRUMemoryCache<String, String>(
            countLimit: 3,
            totalCostLimit: 100
        )
        
        // When: 존재하지 않는 키 조회
        let result = cache.value(key: "missing")
        
        // Then: nil 반환
        #expect(result == nil)
    }
    
    @Test("countLimit 초과 시 LRU 항목이 제거된다")
    func evictsLeastRecentlyUsedWhenCountLimitExceeded() {
        // Given: countLimit = 2
        let cache = LRUMemoryCache<String, String>(
            countLimit: 2,
            totalCostLimit: 100
        )
        
        // When: 3개 삽입
        cache.insert(value: "A", key: "a", cost: 10)
        cache.insert(value: "B", key: "b", cost: 10)
        cache.insert(value: "C", key: "c", cost: 10)
        
        // Then: 가장 오래된 A 제거
        #expect(cache.value(key: "a") == nil)
        #expect(cache.value(key: "b") == "B")
        #expect(cache.value(key: "c") == "C")
    }
    
    @Test("조회된 항목은 MRU로 이동하여 eviction 대상에서 제외된다")
    func accessedItemBecomesMostRecentlyUsed() {
        // Given: A, B 삽입
        let cache = LRUMemoryCache<String, String>(
            countLimit: 2,
            totalCostLimit: 100
        )
        
        cache.insert(value: "A", key: "a", cost: 10)
        cache.insert(value: "B", key: "b", cost: 10)
        
        // When: A를 조회하여 MRU로 만듦
        _ = cache.value(key: "a")
        
        // 그리고 C 삽입 (eviction 발생)
        cache.insert(value: "C", key: "c", cost: 10)
        
        // Then: B가 제거되고 A는 유지된다
        #expect(cache.value(key: "a") == "A")
        #expect(cache.value(key: "b") == nil)
        #expect(cache.value(key: "c") == "C")
    }
    
    @Test("totalCostLimit 초과 시 LRU 항목부터 제거된다")
    func evictsLeastRecentlyUsedWhenTotalCostLimitExceeded() {
        // Given: totalCostLimit = 25
        let cache = LRUMemoryCache<String, String>(
            countLimit: 10,
            totalCostLimit: 25
        )
        
        // When: cost 합이 초과되도록 삽입
        cache.insert(value: "A", key: "a", cost: 10)
        cache.insert(value: "B", key: "b", cost: 10)
        cache.insert(value: "C", key: "c", cost: 10)
        
        // Then: LRU인 A 제거
        #expect(cache.value(key: "a") == nil)
        #expect(cache.value(key: "b") == "B")
        #expect(cache.value(key: "c") == "C")
    }
    
    @Test("동일 키 삽입 시 값을 갱신하고 MRU로 이동한다")
    func updateExistingValueAndMoveToHead() {
        // Given: A, B 삽입
        let cache = LRUMemoryCache<String, String>(
            countLimit: 2,
            totalCostLimit: 100
        )
        
        cache.insert(value: "A", key: "a", cost: 10)
        cache.insert(value: "B", key: "b", cost: 10)
        
        // When: A를 업데이트 후 C 삽입
        cache.insert(value: "A-updated", key: "a", cost: 20)
        cache.insert(value: "C", key: "c", cost: 10)
        
        // Then: A는 최신값 유지, B는 제거
        #expect(cache.value(key: "a") == "A-updated")
        #expect(cache.value(key: "b") == nil)
        #expect(cache.value(key: "c") == "C")
    }
    
    @Test("특정 키 삭제 시 해당 값만 제거된다")
    func removeSpecificValue() {
        // Given: A, B 삽입
        let cache = LRUMemoryCache<String, String>(
            countLimit: 3,
            totalCostLimit: 100
        )
        
        cache.insert(value: "A", key: "a", cost: 10)
        cache.insert(value: "B", key: "b", cost: 10)
        
        // When: A 삭제
        cache.removeValue(key: "a")
        
        // Then: A만 제거되고 B는 유지
        #expect(cache.value(key: "a") == nil)
        #expect(cache.value(key: "b") == "B")
    }
    
    @Test("removeAll 호출 시 모든 값이 제거된다")
    func removeAllValues() {
        // Given: A, B 삽입
        let cache = LRUMemoryCache<String, String>(
            countLimit: 3,
            totalCostLimit: 100
        )
        
        cache.insert(value: "A", key: "a", cost: 10)
        cache.insert(value: "B", key: "b", cost: 10)
        
        // When: 전체 삭제
        cache.removeAll()
        
        // Then: 모든 값 제거
        #expect(cache.value(key: "a") == nil)
        #expect(cache.value(key: "b") == nil)
    }
    
    @Test("insertImage는 이미지 기반 cost 계산으로 저장된다")
    func insertImageStoresImage() {
        // Given: 이미지 캐시
        let cache = LRUMemoryCache<URL, UIImage>(
            countLimit: 10,
            totalCostLimit: 1_000_000
        )
        
        let url = URL(string: "https://example.com/image.png")!
        let image = makeImage(size: CGSize(width: 10, height: 10), scale: 2)
        
        // When: 이미지 삽입
        cache.insertImage(image, key: url)
        
        // Then: 정상 저장됨
        #expect(cache.value(key: url) != nil)
    }
}

// MARK: - Helper
private extension MemoryCacheTests {
    
    func makeImage(size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
