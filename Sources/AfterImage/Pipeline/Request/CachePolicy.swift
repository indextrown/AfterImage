//
//  CachePolicy.swift
//  AfterImage
//
//  Created by 김동현 on 4/14/26.
//

import Foundation

/// 이미지 요청에서 캐시를 어떻게 읽고 쓸지 정의하는 정책입니다.
public enum CachePolicy: Sendable, Equatable {
    /// 메모리 캐시 -> 디스크 캐시 -> 네트워크 순서로 조회하고
    /// 네트워크에서 받은 결과는 다시 캐시에 저장합니다.
    case useCache
    
    /// 기존 캐시를 읽지 않고 네트워크에서 새로 받아옵니다.
    /// 받은 결과는 다시 캐시에 저장합니다.
    case reloadIgnoringCache
    
    /// 캐시에 있는 값만 반환하고, 캐시 miss일 경우 네트워크 요청을 하지 않습니다.
    case returnCacheDataDontLoad
    
    /// 메모리 캐시만 사용합니다.
    /// 디스크 캐시는 읽거나 쓰지 않습니다.
    /// 메모리 캐시 miss 시에는 네트워크 로드를 허용하며, 결과는 메모리에만 기록합니다.
    case memoryOnly
    
    /// 디스크 캐시만 사용합니다.
    /// 메모리 캐시는 읽거나 쓰지 않습니다.
    /// 디스크 캐시 miss 시에는 네트워크 로드를 허용하며, 결과는 디스크에만 기록합니다.
    case diskOnly
}

/// 이미지 로딩 파이프라인에서 if문으로 쉽게 판단하기 위함입니다.
public extension CachePolicy {
    var allowsMemoryRead: Bool {
        switch self {
        case .useCache, .returnCacheDataDontLoad, .memoryOnly:
            return true
        case .reloadIgnoringCache, .diskOnly:
            return false
        }
    }
    
    var allowsDiskRead: Bool {
        switch self {
        case .useCache, .returnCacheDataDontLoad, .diskOnly:
            return true
        case .reloadIgnoringCache, .memoryOnly:
            return false
        }
    }
    
    var allowsNetworkLoad: Bool {
        switch self {
        case .useCache, .reloadIgnoringCache, .memoryOnly, .diskOnly:
            return true
        case .returnCacheDataDontLoad:
            return false
        }
    }
    
    var allowsMemoryWrite: Bool {
        switch self {
        case .useCache, .reloadIgnoringCache, .memoryOnly:
            return true
        case .returnCacheDataDontLoad, .diskOnly:
            return false
        }
    }
    
    var allowsDiskWrite: Bool {
        switch self {
        case .useCache, .reloadIgnoringCache, .diskOnly:
            return true
        case .returnCacheDataDontLoad, .memoryOnly:
            return false
        }
    }
}
