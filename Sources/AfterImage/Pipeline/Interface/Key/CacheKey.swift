//
//  CacheKey.swift
//  AfterImage
//
//  Created by 김동현 on 4/14/26.
//

import Foundation

/// 캐시에서 하나의 이미지 결과물을 식별하는 키입니다.
///
/// 디스크 캐시는 이 값을 그대로 파일명으로 쓰기보다,
/// 기존 `DiskCache` 내부에서 해시 파일명으로 변환해서 쓰는 방향이 좋습니다.
public struct CacheKey: Hashable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
