//
//  CachePolicyTests.swift
//  AfterImage
//
//  Created by 김동현 on 4/14/26.
//

import Testing
@testable import AfterImage

struct CachePolicyTests {
    
    @Test("useCache는 메모리/디스크 읽기와 쓰기, 네트워크 로드를 모두 허용한다")
    func useCache_allowsExpectedBehaviors() {
        let policy = CachePolicy.useCache
        
        #expect(policy.allowsMemoryRead == true)
        #expect(policy.allowsDiskRead == true)
        #expect(policy.allowsNetworkLoad == true)
        #expect(policy.allowsMemoryWrite == true)
        #expect(policy.allowsDiskWrite == true)
    }
    
    @Test("reloadIgnoringCache는 캐시 읽기를 허용하지 않고 네트워크 로드와 캐시 쓰기를 허용한다")
    func reloadIgnoringCache_allowsExpectedBehaviors() {
        let policy = CachePolicy.reloadIgnoringCache
        
        #expect(policy.allowsMemoryRead == false)
        #expect(policy.allowsDiskRead == false)
        #expect(policy.allowsNetworkLoad == true)
        #expect(policy.allowsMemoryWrite == true)
        #expect(policy.allowsDiskWrite == true)
    }
    
    @Test("returnCacheDataDontLoad는 캐시 읽기만 허용하고 네트워크 로드와 캐시 쓰기는 허용하지 않는다")
    func returnCacheDataDontLoad_allowsExpectedBehaviors() {
        let policy = CachePolicy.returnCacheDataDontLoad
        
        #expect(policy.allowsMemoryRead == true)
        #expect(policy.allowsDiskRead == true)
        #expect(policy.allowsNetworkLoad == false)
        #expect(policy.allowsMemoryWrite == false)
        #expect(policy.allowsDiskWrite == false)
    }
    
    @Test("memoryOnly는 메모리 읽기/쓰기와 네트워크 로드를 허용하고 디스크 접근은 허용하지 않는다")
    func memoryOnly_allowsExpectedBehaviors() {
        let policy = CachePolicy.memoryOnly
        
        #expect(policy.allowsMemoryRead == true)
        #expect(policy.allowsDiskRead == false)
        #expect(policy.allowsNetworkLoad == true)
        #expect(policy.allowsMemoryWrite == true)
        #expect(policy.allowsDiskWrite == false)
    }
    
    @Test("diskOnly는 디스크 읽기/쓰기와 네트워크 로드를 허용하고 메모리 접근은 허용하지 않는다")
    func diskOnly_allowsExpectedBehaviors() {
        let policy = CachePolicy.diskOnly
        
        #expect(policy.allowsMemoryRead == false)
        #expect(policy.allowsDiskRead == true)
        #expect(policy.allowsNetworkLoad == true)
        #expect(policy.allowsMemoryWrite == false)
        #expect(policy.allowsDiskWrite == true)
    }
    
    @Test("CachePolicy는 같은 case끼리 같고 다른 case끼리는 다르다")
    func equatable_worksAsExpected() {
        #expect(CachePolicy.useCache == .useCache)
        #expect(CachePolicy.memoryOnly == .memoryOnly)
        #expect(CachePolicy.useCache != .diskOnly)
        #expect(CachePolicy.reloadIgnoringCache != .returnCacheDataDontLoad)
    }
}
