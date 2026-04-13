//
//  DiskCacheConfiguration.swift
//  AfterImage
//
//  Created by 김동현 on 4/13/26.
//

import Foundation

/// 디스크 캐시의 저장 위치와 동작 정책을 정의하는 설정 타입입니다.
///
/// 이 설정값을 통해
/// - 캐시를 어느 디렉터리에 저장할지
/// - 기본 만료 시간을 얼마로 둘지
/// - 최대 몇 개까지 저장할지
/// - 전체 용량을 얼마까지 허용할지
/// 를 제어할 수 있습니다.
public struct DiskCacheConfiguration: Sendable {
    
    /// 캐시 데이터 파일과 메타데이터 파일을 저장할 디렉터리 URL입니다.
    public let directoryURL: URL
    
    /// 개별 저장 시 TTL을 별도로 주지 않았을 때 사용할 기본 TTL입니다.
    ///
    /// `nil`이면 기본적으로 만료되지 않는 캐시로 동작합니다.
    public let defaultTTL: TimeInterval?
    
    /// 디스크 캐시에 저장할 수 있는 최대 항목 개수입니다.
    ///
    /// 이 값을 초과하면 오래 접근하지 않은 항목부터 제거됩니다.
    public let countLimit: Int
    
    /// 디스크 캐시에 저장할 수 있는 최대 총 용량(바이트)입니다.
    ///
    /// 이 값을 초과하면 오래 접근하지 않은 항목부터 제거됩니다.
    public let totalSizeLimit: Int
    
    /// 디스크 캐시 설정값을 생성합니다.
    ///
    /// - Parameters:
    ///   - directoryURL: 캐시 파일이 저장될 디렉터리입니다.
    ///   - defaultTTL: 기본 TTL입니다. `nil`이면 기본적으로 만료되지 않습니다.
    ///   - countLimit: 최대 캐시 개수입니다.
    ///   - totalSizeLimit: 최대 총 캐시 크기(바이트)입니다.
    public init(
        directoryURL: URL,
        defaultTTL: TimeInterval?,
        countLimit: Int,
        totalSizeLimit: Int
    ) {
        self.directoryURL = directoryURL
        self.defaultTTL = defaultTTL
        self.countLimit = countLimit
        self.totalSizeLimit = totalSizeLimit
    }
}
