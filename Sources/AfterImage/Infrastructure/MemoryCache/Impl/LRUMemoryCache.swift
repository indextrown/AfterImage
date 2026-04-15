//
//  LRUMemoryCache.swift
//  AfterImage
//
//  Created by 김동현 on 4/11/26.
//

import UIKit

public final class LRUMemoryCache<
    Key: Hashable,
    Value
>: MemoryCacheType {
    
    /// 연결 리스트 내에서 O(1) 이동/삭제를 위해 참조 타입 사용
    private final class Node {
        let key: Key
        var value: Value
        var cost: Int
        var prev: Node?
        var next: Node?
        
        init(
            key: Key,
            value: Value,
            cost: Int
        ) {
            self.key = key
            self.value = value
            self.cost = cost
        }
    }
    
    private let lock = NSLock()
    private let configuration: MemoryCacheConfiguration
    
    private var nodes: [Key: Node] = [:] // key로 노드를 바로 찾기 위함
    private var totalCost = 0
    private var head: Node? // 가장 최근 사용한 노드
    private var tail: Node? // 가장 오래 사용하지 않은 노드
    
    
    /// 메모리 캐시 정책을 담은 configuration을 사용해 LRU 메모리 캐시를 생성합니다.
    ///
    /// - Parameter configuration:
    ///   캐시의 최대 개수(`countLimit`)와 총 cost 제한(`totalCostLimit`)을 정의한 설정값
    public init(configuration: MemoryCacheConfiguration) {
        self.configuration = configuration
    }
    
    /// 저장 개수 제한과 전체 cost 제한을 직접 지정해 LRU 메모리 캐시를 생성합니다.
    ///
    /// - Parameters:
    ///   - countLimit: 캐시에 저장할 수 있는 최대 항목 개수입니다.
    ///   - totalCostLimit: 캐시에 저장할 수 있는 전체 최대 cost 값입니다.
    public convenience init(
        countLimit: Int,
        totalCostLimit: Int
    ) {
        let configuration = MemoryCacheConfiguration(
            countLimit: countLimit,
            totalCostLimit: totalCostLimit
        )
        self.init(configuration: configuration)
    }
    
    /// 기본 설정으로 생성 가능한 이니셜라이저
    public convenience init() {
        self.init(configuration: MemoryCacheConfiguration())
    }
}

// MARK: - Private
extension LRUMemoryCache {
    /// 노드를 연결 리스트의 head(MRU 위치)에 삽입합니다.
    ///
    /// - Parameter node: 삽입할 노드
    ///
    /// - Note:
    ///   - 해당 노드는 가장 최근에 사용된 상태가 됩니다.
    ///   - 기존 head 앞에 위치하게 되며, tail이 없을 경우 초기화됩니다.
    ///
    /// - Complexity: O(1)
    private func insertAtHead(_ node: Node) {
        node.prev = nil
        node.next = head
        
        head?.prev = node
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    /// 특정 노드를 연결 리스트에서 제거합니다.
    ///
    /// - Parameter node: 제거할 노드
    ///
    /// - Note:
    ///   - prev / next 연결을 끊고 리스트에서 완전히 분리합니다.
    ///   - head 또는 tail일 경우 각각 갱신됩니다.
    ///
    /// - Complexity: O(1)
    private func removeNode(_ node: Node) {
        let prev = node.prev
        let next = node.next
        
        prev?.next = next
        next?.prev = prev
        
        if head === node {
            head = next
        }
        
        if tail === node {
            tail = prev
        }
        
        node.prev = nil
        node.next = nil
    }
    
    /// 노드를 head(MRU 위치)로 이동시킵니다.
    ///
    /// - Parameter node: 이동할 노드
    ///
    /// - Note:
    ///   - 이미 head인 경우 아무 작업도 수행하지 않습니다.
    ///   - 내부적으로 remove → insert 순으로 처리됩니다.
    ///
    /// - Complexity: O(1)
    private func moveToHead(_ node: Node) {
        guard head !== node else {
            return
        }
        
        removeNode(node)
        insertAtHead(node)
    }
    
    /// 캐시 용량 제한을 초과했을 경우 LRU 노드를 제거합니다.
    ///
    /// - Note:
    ///   - `countLimit` 또는 `totalCostLimit`을 초과하면 실행됩니다.
    ///   - 가장 오래 사용되지 않은 노드(tail)부터 제거합니다.
    ///   - 조건을 만족할 때까지 반복적으로 제거됩니다.
    ///
    /// - Complexity:
    ///   - 평균적으로 각 제거는 O(1)
    ///   - 한 번의 eviction 과정에서 여러 노드를 제거할 수 있어 최악의 경우 O(n)
    private func evictIfNeeded() {
        while nodes.count > configuration.countLimit ||
                totalCost > configuration.totalCostLimit {
            guard let leastRecentlyUsedNode = tail else {
                return
            }
            
            nodes.removeValue(forKey: leastRecentlyUsedNode.key)
            totalCost -= leastRecentlyUsedNode.cost
            removeNode(leastRecentlyUsedNode)
        }
    }
}

// MARK: - Public
public extension LRUMemoryCache {
    
    func value(key: Key) -> Value? {
        // 캐시 내부 데이터에 동시에 접근하지 못하게 잠금
        /// 한 번에 한 스레드만 이 코드를 실행하게 하는 잠금 장치
        lock.lock()

        // 함수가 끝날 때 반드시 잠금 해제
        /// 잠금을 걸어 다른 스레드가 수정 중이라면 현재 스레드는 잠금이 풀릴 때까지 대기한다
        defer { lock.unlock() }
        
        // key에 해당하는 node가 없으면 nil 반환
        guard let node = nodes[key] else {
            return nil
        }
        
        // 조회된 항목을 최근 사용된 항목으로 이동
        moveToHead(node)
        
        // 실제 캐시 값 반환
        return node.value
    }
    
    func insert(value: Value, key: Key, cost: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        if let node = nodes[key] {
            totalCost -= node.cost
            node.value = value
            node.cost = cost
            totalCost += cost
            moveToHead(node)
            evictIfNeeded()
            return
        }
        
        let node = Node(key: key, value: value, cost: cost)
        nodes[key] = node
        totalCost += cost
        insertAtHead(node)
        evictIfNeeded()
    }
    
    func removeValue(key: Key) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let node = nodes.removeValue(forKey: key) else {
            return
        }
        
        totalCost -= node.cost
        removeNode(node)
    }
    
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        
        nodes.removeAll()
        totalCost = 0
        head = nil
        tail = nil
    }
}

// MARK: - Image
public extension LRUMemoryCache where Key == URL, Value == UIImage {
    
    /// UIImage의 메모리 사용량을 바이트 단위로 계산합니다.
    ///
    /// - Note:
    ///   - 실제 메모리 사용량은 `cgImage`의 픽셀 크기를 기준으로 계산합니다.
    ///   - `cgImage.width`와 `cgImage.height`는 실제 픽셀 수를 나타냅니다.
    ///   - 일반적으로 디코딩된 이미지는 RGBA(4 byte per pixel) 포맷을 사용한다고 가정합니다.
    ///   - 최종 cost = width × height × 4 (근사값)
    ///
    /// - Note:
    ///   - 현재는 URL 기반의 단순 이미지 캐시를 사용합니다.
    ///   - 향후 target size, scale, processor 등 variant를 구분해야 하는 경우
    ///     별도의 CacheKey 모델로 확장할 수 있습니다.
    ///
    /// - Example:
    ///   - cgImage.width: 300, cgImage.height: 300
    ///   - → cost: 300 × 300 × 4 = 360,000 bytes
    ///
    /// - Parameters:
    ///   - image: 캐시에 저장할 UIImage
    ///   - key: 이미지 식별을 위한 URL 키
    @available(*, deprecated, message: "Use insertImage(_ image: UIImage, key: Key) instead.")
    func insertImage(_ image: UIImage, key: URL) {
        
        guard let cgimage = image.cgImage else { return }
        
        let width = cgimage.width
        let height = cgimage.height
        let cost = width * height * 4
        
        insert(value: image, key: key, cost: cost)
    }
}

// MARK: - Image
public extension LRUMemoryCache where Value == UIImage {

    /// `UIImage`를 메모리 캐시에 저장합니다.
    ///
    /// 이미지의 메모리 사용량을 추정하여 `cost`를 계산한 뒤,
    /// LRU 캐시에 삽입합니다.
    ///
    /// - Parameters:
    ///   - image: 캐시에 저장할 `UIImage`
    ///   - key: 캐시 식별 키
    ///
    /// - Note:
    ///   - `UIImage`는 내부적으로 `cgImage`를 항상 보장하지 않습니다.
    ///     (`CIImage` 기반 이미지 등은 `cgImage`가 nil일 수 있음)
    ///   - 따라서 두 가지 방식으로 메모리 cost를 계산합니다.
    ///
    ///     1. `cgImage`가 존재하는 경우:
    ///        - 실제 픽셀 크기(`width * height`)를 기반으로 계산
    ///        - RGBA 기준 4 byte per pixel을 가정하여 `width * height * 4`
    ///
    ///     2. `cgImage`가 없는 경우 (fallback):
    ///        - `UIImage.size`(point 단위)에 `scale`을 곱해 픽셀 크기로 변환
    ///        - `pixelWidth = size.width * scale`
    ///        - `pixelHeight = size.height * scale`
    ///        - 최소값 1로 보정하여 0 크기 방지
    ///
    /// - Important:
    ///   - `cgImage`가 없다고 해서 저장을 건너뛰지 않고,
    ///     fallback 계산을 통해 일관된 캐시 동작을 유지합니다.
    ///   - 이는 이미지 내부 표현 방식에 따라 캐시 hit/miss가 달라지는 문제를 방지합니다.
    ///
    /// - Discussion:
    ///   - 메모리 캐시는 cost 기반 eviction을 수행하므로,
    ///     가능한 한 실제 메모리 사용량에 근접한 값으로 계산하는 것이 중요합니다.
    ///   - 이 구현은 정확한 byte 측정이 아닌, 성능과 단순성을 고려한 근사치입니다.
    func insertImage(_ image: UIImage, key: Key) {
        let cost: Int

        if let cgImage = image.cgImage {
            cost = cgImage.width * cgImage.height * 4
        } else {
            let pixelWidth = max(Int((image.size.width * image.scale).rounded(.up)), 1)
            let pixelHeight = max(Int((image.size.height * image.scale).rounded(.up)), 1)
            cost = pixelWidth * pixelHeight * 4
        }

        insert(value: image, key: key, cost: cost)
    }
}
