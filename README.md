# AfterImage
`AfterImage`는 iOS 앱에서 반복되는 이미지 다운로드 비용을 줄이기 위해 만드는 Swift 기반 이미지 캐시 라이브러리입니다.

<!--현재 목표는 단순한 `URL -> UIImage` 헬퍼가 아니라, 메모리 캐시와 디스크 캐시를 기반으로 한 request-aware image pipeline을 만드는 것입니다.-->

## 파이프라인
![AfterImage Pipeline](Pipeline.png)

## 구현 방향
기본 이미지 로딩 흐름은 아래 순서를 따릅니다.

```text
ImageRequest
  -> CacheKey / VariantKey 생성
  -> MemoryCache 조회
  -> DiskCache 조회
  -> Network 다운로드
  -> ImageDecoder / Downsampling
  -> ImageProcessor 적용
  -> MemoryCache + DiskCache 저장
  -> UIImage 반환
```

## 구현 순서
- [x] 패키지 기본 구조 생성
- [x] 메모리 캐시 인터페이스 정의
- [x] 메모리 캐시 설정 타입 구현
- [x] LRU 기반 메모리 캐시 구현
- [x] 메모리 캐시 테스트 작성
- [x] 디스크 캐시 인터페이스 정의
- [x] 디스크 캐시 설정 타입 구현
- [x] actor 기반 디스크 캐시 구현
- [x] 디스크 캐시 테스트 작성
- [x] `ImageRequest` 구현
- [x] `CachePolicy` 구현
- [x] `ImageProcessor` 인터페이스 구현
- [x] `CacheKey` / `VariantKey` 구현
- [x] `DataLoaderType` 인터페이스 구현
- [x] `URLSessionDataLoader` 구현
- [x] `ImageDecoderType` 인터페이스 구현
- [x] `ImageDecoder` + downsampling 구현
- [x] `ImagePipelineType` 인터페이스 구현
- [x] `ImagePipeline` actor 구현
- [ ] 중복 요청 방지(in-flight dedupe) 구현
- [x] ImagePipeline 테스트 작성
- [ ] SwiftUI 어댑터 구현
- [ ] UIKit 어댑터 구현
- [ ] README 사용 예제 정리

## 계층 구조
```text
UI Layer
  -> SwiftUI Adapter / UIKit Adapter

Pipeline Layer
  -> ImageRequest
  -> CachePolicy
  -> CacheKey / VariantKey
  -> ImagePipeline
  -> In-flight Dedupe

Infrastructure Layer
  -> LRUMemoryCache
  -> DiskCache
  -> DataLoader
  -> ImageDecoder
  -> ImageProcessor
```

## 현재 상태
현재까지는 캐시 계층이 중심입니다.

- `LRUMemoryCache`는 직접 구현한 LRU 정책을 사용합니다.
- `DiskCache`는 actor 기반 파일 캐시로 구현되어 있습니다.
- 디스크 캐시는 TTL, count limit, total size limit, 손상된 metadata 정리를 고려합니다.
- 다음 단계는 UI가 아니라 `ImageRequest`, `CachePolicy`, `CacheKey` / `VariantKey`를 먼저 만드는 것입니다.

## V1 Non-goals
처음 버전에서는 아래 항목을 우선순위에서 제외합니다.
- HTTP cache-control 완전 준수
- progressive decoding
- animated image 지원
- 복잡한 prefetch scheduler
- cross-platform generalization


<!--# AfterImage-->
<!---->
<!--`AfterImage`는 iOS 앱에서 반복되는 이미지 다운로드 비용을 줄이기 위해 만드는 Swift 기반 이미지 캐시 라이브러리입니다.-->
<!---->
<!--지금은 패키지 구조를 먼저 잡아둔 초기 단계이며, README도 "이미 완성된 기능 소개"보다는 우리가 어떤 문제를 풀고 어떤 방향으로 설계할지를 중심으로 정리합니다.-->
<!---->
<!--## Why AfterImage-->
<!---->
<!--이미지 로딩은 앱에서 아주 흔한 작업이지만, 실제로는 아래 같은 문제가 자주 따라옵니다.-->
<!---->
<!--- 같은 URL을 여러 번 요청하면서 불필요한 네트워크 비용이 발생함-->
<!--- 스크롤이 많은 화면에서 이미지 로딩 타이밍이 UI 경험에 직접 영향을 줌-->
<!--- 메모리 캐시와 디스크 캐시 정책이 분리되지 않으면 동작을 예측하기 어려움-->
<!--- 뷰 레벨 API와 캐시 레벨 API가 섞이면 사용성도 떨어지고 테스트도 어려워짐-->
<!---->
<!--`AfterImage`는 이 문제를 작은 규모의 앱부터 점진적으로 적용할 수 있는 형태로 풀어내는 것을 목표로 합니다.-->
<!---->
<!--## Design Goals-->
<!---->
<!--- 빠른 체감 성능을 위한 메모리 캐시 우선 전략-->
<!--- 앱 재실행 이후에도 재사용 가능한 디스크 캐시-->
<!--- 동일 리소스에 대한 중복 요청 억제-->
<!--- UIKit/SwiftUI 어디서든 붙일 수 있는 단순한 API-->
<!--- 동작을 설명할 수 있는 예측 가능한 캐시 정책-->
<!---->
<!--## Direction-->
<!---->
<!--현재 생각하는 기본 흐름은 아래와 같습니다.-->
<!---->
<!--```text-->
<!--Request-->
<!--  -> Memory Cache-->
<!--  -> Disk Cache-->
<!--  -> Network-->
<!--  -> Store to Memory + Disk-->
<!--  -> Return Image-->
<!--```-->
<!---->
<!--구현이 진행되면 다음 항목들을 핵심 축으로 다룰 예정입니다.-->
<!---->
<!--- Memory cache-->
<!--  - 빠른 조회와 교체 정책이 명확한 구조-->
<!--- Disk cache-->
<!--  - 파일 기반 저장-->
<!--  - 만료 정책과 용량 제한-->
<!--- Image pipeline-->
<!--  - 다운로드, 디코딩, 캐시 저장 흐름 분리-->
<!--- View integration-->
<!--  - SwiftUI와 UIKit에서 모두 쓰기 쉬운 형태-->
<!---->
<!--## Principles-->
<!---->
<!--참고한 여러 이미지 캐시 라이브러리의 장점은 가져오되, `AfterImage`는 아래 기준을 더 중요하게 봅니다.-->
<!---->
<!--- 구현보다 문서를 먼저 맞춘다-->
<!--- 매직한 동작보다 설명 가능한 동작을 택한다-->
<!--- "기능이 많아 보이는" API보다 실제 앱에서 자주 쓰는 흐름을 우선한다-->
<!--- 성능 최적화는 추측이 아니라 측정 가능한 근거와 함께 진행한다-->
<!---->
<!--## Current Status-->
<!---->
<!--현재 저장소는 Swift Package 형태의 초기 스캐폴드만 준비된 상태입니다.-->
<!---->
<!--- Platform: iOS 13+-->
<!--- Package manager: Swift Package Manager-->
<!--- Public API: 아직 설계/구현 전-->
<!--- Cache engine: 아직 구현 전-->
<!--- UI component: 아직 구현 전-->
<!---->
<!--즉, 지금 README는 완성된 라이브러리 문서라기보다 설계 문서에 가까운 첫 버전입니다.-->
<!---->
<!--## Roadmap-->
<!---->
<!--- [ ] 메모리 캐시 계층 설계-->
<!--- [ ] 디스크 캐시 키 전략 정의-->
<!--- [ ] 이미지 다운로드/디코딩 파이프라인 구성-->
<!--- [ ] 중복 요청 방지 로직 추가-->
<!--- [ ] 테스트 코드 작성-->
<!--- [ ] UIKit/SwiftUI용 사용 예제 정리-->
<!--- [ ] 정식 사용법 README로 확장-->
<!---->
<!--## Installation-->
<!---->
<!--패키지 추가는 가능하지만, 아직 실사용 단계는 아닙니다.-->
<!---->
<!--```swift-->
<!--dependencies: [-->
<!--    .package(url: "https://github.com/your-org/AfterImage.git", branch: "main")-->
<!--]-->
<!--```-->
<!---->
<!--## README Plan-->
<!---->
<!--구현이 진행되면 README는 아래 순서로 확장할 예정입니다.-->
<!---->
<!--1. 한 줄 소개-->
<!--2. 핵심 기능-->
<!--3. 설치 방법-->
<!--4. 기본 사용 예제-->
<!--5. 캐시 동작 방식-->
<!--6. 설계 판단과 트레이드오프-->
<!--7. 요구사항 및 로드맵-->
<!---->
<!--## License-->
<!---->
<!--License는 추후 프로젝트 정책에 맞춰 추가할 예정입니다.-->
<!---->
