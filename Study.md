## Darwin이란?
Darwin은 macOS, iOS 등의 기반이 되는 Apple 운영체제의 핵심 계층입니다.
따라서 `Darwin Foundation`은 Apple 플랫폼에서 실제로 동작하는 Foundation 구현을 의미하고,  
`swift-corelibs-foundation`은 Linux 등 비-Darwin 플랫폼에서도 Foundation API를 사용할 수 있도록 공개된 별도 구현입니다.
즉, `swift-corelibs-foundation`의 구현을 확인할 수는 있지만, 이를 그대로 iOS의 실제 동작 방식으로 단정할 수는 없습니다.

## NSCache
- `swift-corelibs-foundation`의 [`NSCache`](https://github.com/swiftlang/swift-corelibs-foundation/blob/main/Sources/Foundation/NSCache.swift) 공개 구현에서는 `최소 비용 우선 교체 방식`을 사용합니다. 
- 다만 이 구현은 **비-Darwin 플랫폼(Windows, Linux)용 오픈소스 구현**입니다.
- 실제 iOS에서 사용하는 `NSCache` 구현은 비공개이며, Apple 공식 문서도 **어떤 교체 알고리즘을 사용하는지 명시하지 않습니다**. 
- 또한 [`countLimit`과 `totalCostLimit` 역시 엄격하게 보장되지 않으며](https://developer.apple.com/documentation/foundation/nscache/totalcostlimit?language=objc&utm_source=chatgpt.com), 제거 시점과 방식은 구현 세부사항에 따라 달라질 수 있습니다.
- **최소 비용 우선 교체 방식**
    - `swift-corelibs-foundation`의 공개 구현에서는 엔트리를 `cost` 기준으로 관리하고, `totalCostLimit` 또는 `countLimit`를 초과하면 앞쪽 엔트리부터 제거합니다.
    - 그 결과, `cost`가 낮은 항목부터 먼저 제거되는 형태로 동작합니다.

## MemoryCache에서 `NSCache`를 제거한 이유
기존에는 `NSCache` 사용을 검토했지만, 캐시 교체 시점을 직접 예측하거나 제어하기 어렵다고 판단해 최종적으로 제외했습니다.
공개된 `swift-corelibs-foundation` 구현에서는 `cost` 기반으로 항목을 정리하는 로직을 확인할 수 있습니다.  
하지만 해당 구현은 비-Darwin 환경을 위한 오픈소스 구현이며, 실제 iOS의 `NSCache`는 비공개로 동작합니다. 
또한 Apple 공식 문서 역시 교체 알고리즘을 명시하지 않기 때문에, 실제 iOS 환경에서 어떤 기준으로 캐시가 제거되는지 확정할 수 없습니다.
캐시 계층에서는 동작의 예측 가능성과 일관성이 중요하다고 판단했습니다.  
그래서 내부 정책이 불명확한 `NSCache` 대신 직접 LRU 캐시를 구현해, 교체 기준을 명확히 하고 동일한 조건에서 일관된 동작을 보장하도록 했습니다.

# Memory Cache(LRU)
자료구조: 이중 연결 리스트 + 해시맵
조회와 삽입 모두 O(1)로 처리하기 위해 두 자료구조를 결합했습니다.
- 해시맵: URL 키로 노드를 O(1)에 찾기
- 이중 연결 리스트: 최근 사용 순서 유지 및 O(1) 노드 이동
```bash
MRU (최근 사용) -------------------- LRU (오래됨)
[head] <-> [A] <-> [B] <-> [C] <-> [tail]
조회: 해당 노드를 head쪽으로 이동
용량 초과: tail쪽 노드 제거
```

# Reference
- [LRU 알고리즘](https://j2wooooo.tistory.com/121)
- https://developer.apple.com/documentation/Foundation/NSCache
- https://jeonyeohun.tistory.com/383
- https://felix-mr.tistory.com/13
- https://github.com/swiftlang/swift-corelibs-foundation/blob/main/Sources/Foundation/NSCache.swift