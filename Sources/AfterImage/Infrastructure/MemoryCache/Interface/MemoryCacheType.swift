//
//  MemoryCacheType.swift
//  AfterImage
//
//  Created by 김동현 on 4/12/26.
//

import Foundation

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
