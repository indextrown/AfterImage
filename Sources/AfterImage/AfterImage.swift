// The Swift Programming Language
// https://docs.swift.org/swift-book

/**
 https://velog.io/@o_joon_/Swift-Image-caching이미지-캐싱
 https://dev-voo.tistory.com/49
 https://heidi-dev.tistory.com/54
 https://trumanfromkorea.tistory.com/84 // 다운샘플링
 https://xerathcoder.tistory.com/279
 https://applecider2020.tistory.com/54 // sha256
 https://kimsangjunzzang.tistory.com/104
 https://ios-development.tistory.com/715
 
 https://ios-adventure-with-aphelios.tistory.com/30
 https://velog.io/@o_joon_/Swift-Image-caching이미지-캐싱
 https://codeisfuture.tistory.com/121

 
 prefetch
 https://ios-development.tistory.com/715
 
 동시성
 https://ios-adventure-with-aphelios.tistory.com/30
 
 캐싱플로우
 https://ios-adventure-with-aphelios.tistory.com/30
 
 얕은복사
 https://heidi-dev.tistory.com/54
 
 제라스
 https://xerathcoder.tistory.com/279
 
 https://codeisfuture.tistory.com/121
 */

/*
 https://velog.io/@o_joon_/Swift-Image-caching이미지-캐싱
 https://dev-voo.tistory.com/49
 https://babbab2.tistory.com/164 // 클로저
 https://kimsangjunzzang.tistory.com/104
 
 2-Layer Cache 전략
 Memory Cache(1차 방어선) : 가장 빠른 RAM에서 먼저 찾아본다.
 Disk Cache(2차 방어선) : Memory에 없으면 디스크에서 찾아봅니다. 찾았다면, 다음 접근을 위해 Memory에도 올려놓습니다.
 Network(최후) : 둘다 없으면, 네트워크에서 다운로드하여 Memory와 Disk 양쪽에 모두 저장합니다.
 
 NSCache
 - 리소스가 부족할 때 제거될 수 있으며 임시로 키-값 쌍을 사용하는 변경 가능한 컬렉션
 - 캐시가 메모리를 너무 많이 사용하지 않도록 자동으로 캐시 제거
 
 let cache = NSCache<NSString, UIImage>()
 - String이 아닌 NSString이 쓰이는 이유
 - NSCache가 Objective-C 기반 클래스(NSObject)이기 때문에 swift와 objectivec의 호완성을 위해 NSString을 쓴다
 
 클로저
 - 기본적으로 파라미터로 받는 "클로저"는 함수 흐름을 탈출하지 못한다
 - escaping 키워드를 붙여주면 이 클로저는 함수 실행 흐름에 상관 없이 실행되는 클로저라고 알려주는 것이다
 - 함수 파라미터의 클로저가 옵셔널 타입인 경우 자동으로 escaping으로 동작한다
 */

import UIKit
