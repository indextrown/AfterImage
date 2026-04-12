//
//  MemoryCacheConfiguration.swift
//  AfterImage
//
//  Created by 김동현 on 4/12/26.
//

import Foundation

/// 메모리 캐시 정책을 정의하는 설정값입니다.
///
/// `countLimit`와 `totalCostLimit`를 통해
/// 캐시에 저장할 최대 항목 수와 전체 비용 한도를 지정합니다.
///
/// 이 타입은 불변 값으로만 구성되어 있어
/// 동시성 환경에서도 안전하게 전달할 수 있도록 `Sendable`을 채택합니다.
public struct MemoryCacheConfiguration: Sendable {
    
    /// 캐시에 저장할 수 있는 최대 항목 개수입니다.
    public let countLimit: Int
    
    /// 캐시에 저장할 수 있는 전체 비용의 최대 한도입니다.
    ///
    /// 일반적으로 바이트 단위의 메모리 비용을 의미합니다.
    public let totalCostLimit: Int
    
    /// 메모리 캐시 설정값을 생성합니다.
    ///
    /// - Parameters:
    ///   - countLimit: 캐시에 저장할 수 있는 최대 항목 개수입니다. 기본값은 `100`입니다.
    ///   - totalCostLimit: 캐시에 저장할 수 있는 전체 비용의 최대 한도입니다. 기본값은 `50 * 1024 * 1024`(50MB)입니다.
    ///
    /// - Precondition:
    ///   - `countLimit`는 0보다 커야 합니다.
    ///   - `totalCostLimit`는 0보다 커야 합니다.
    public init(
        countLimit: Int = 100,
        totalCostLimit: Int = 50 * 1024 * 1024
    ) {
        precondition(countLimit > 0, "countLimit must be greater than 0")
        precondition(totalCostLimit > 0, "totalCostLimit must be greater than 0")
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
    }
}
