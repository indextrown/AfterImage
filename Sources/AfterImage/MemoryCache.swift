//
//  MemoryCache.swift
//  AfterImage
//
//  Created by 김동현 on 4/11/26.
//

import UIKit

// MARK: - Interface
public protocol MemoryCacheType<Key, Value>: AnyObject {
    associatedtype Key: Hashable // cache dictionary key
    associatedtype Value         // value
    
    /// 주어진 키에 해당하는 값을 조회합니다.
    ///
    /// - Parameter key: 조회할 캐시 키
    /// - Returns: 해당 키에 저장된 값. 없으면 `nil`
    ///
    /// - Note:
    ///   - 조회 성공 시, 해당 항목은 **최근 사용(MRU)** 상태로 갱신됩니다.
    ///   - 내부적으로 노드를 `head`로 이동시켜 LRU 순서를 유지합니다.
    func value(key: Key) -> Value? // 조회
    
    /// 값을 캐시에 저장합니다.
    ///
    /// - Parameters:
    ///   - value: 저장할 값
    ///   - key: 캐시 키
    ///   - cost: 해당 값의 비용 (메모리 크기 등)
    ///
    /// - Note:
    ///   - 동일한 키가 존재하면 기존 값을 갱신하고 **최근 사용 상태로 이동**합니다.
    ///   - 삽입 후 `countLimit` 또는 `totalCostLimit`을 초과하면
    ///     **가장 오래 사용되지 않은(LRU) 항목부터 제거**됩니다.
    func insert(value: Value, key: Key, cost: Int) // 저장
    
    /// 특정 키에 해당하는 값을 제거합니다.
    ///
    /// - Parameter key: 제거할 캐시 키
    ///
    /// - Note:
    ///   - 해당 키가 존재하지 않으면 아무 동작도 하지 않습니다.
    ///   - 제거 시 연결 리스트와 총 cost도 함께 갱신됩니다.
    func removeValue(key: Key) // 특정 키 삭제
    
    /// 캐시에 저장된 모든 값을 제거합니다.
    ///
    /// - Note:
    ///   - 내부 딕셔너리와 연결 리스트를 모두 초기화합니다.
    ///   - `totalCost`도 0으로 리셋됩니다.
    func removeAll() // 전체 삭제
}

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
    private let countLimit: Int     // 캐시에 들어갈 아이템 개수 제한(개)
    private let totalCostLimit: Int // 캐시에 저장된 메모리 크기 제한(byte)
    
    private var nodes: [Key: Node] = [:] // key로 노드를 바로 찾기 위함
    private var totalCost = 0
    private var head: Node? // 가장 최근 사용한 노드
    private var tail: Node? // 가장 오래 사용하지 않은 노드
    
    public init(countLimit: Int, totalCostLimit: Int) {
        precondition(countLimit > 0, "countLinit must be greater than 0")
        precondition(totalCostLimit > 0, "totalCostLimit must be greater than 0")
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
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
        while nodes.count > countLimit || totalCost > totalCostLimit {
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
    /// (Legacy)
    ///   - `UIImage.size`는 point 단위이므로, 실제 픽셀 수를 구하기 위해 `scale`을 곱합니다.
    ///   - 픽셀 수 = (width * scale) × (height * scale)
    ///   - 일반적으로 디코딩된 이미지는 RGBA(4byte per pixel) 포맷을 사용한다고 가정합니다.
    ///   - 실제 메모리 사용량은 이미지 포맷에 따라 다를 수 있습니다.
    ///   - 최종 cost = 픽셀 수 × 4byte (근사값)
    ///
    /// - Example:
    ///   - size: 100 x 100, scale: 3
    ///   - → 실제 픽셀: 300 x 300
    ///   - → cost: 300 × 300 × 4 = 360,000 bytes
    ///
    /// - Parameters:
    ///   - image: 캐시에 저장할 UIImage
    ///   - key: 이미지 식별을 위한 URL 키
    ///
    
    
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
    func insertImage(_ image: UIImage, key: URL) {
        
        guard let cgimage = image.cgImage else { return }
        
        let width = cgimage.width
        let height = cgimage.height
        let cost = width * height * 4
        
        insert(value: image, key: key, cost: cost)
    }
}
