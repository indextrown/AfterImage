//
//  File.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import UIKit

/// 이미지 요청을 받아 최종 `UIImage`를 반환하는 파이프라인 인터페이스입니다.
///
/// UI 계층은 구체 구현체인 `ImagePipeline`보다 이 프로토콜에 의존할 수 있습니다.
public protocol ImagePipelineType: Sendable {
    
    /// 이미지 요청을 처리하고 최종 이미지를 반환합니다.
    ///
    /// - Parameter request: 이미지 로딩 요청
    /// - Returns: 캐시 또는 네트워크/디코딩 과정을 거쳐 얻은 `UIImage`
    /// - Throws: 캐시 miss, 네트워크 실패, 디코딩 실패, 디스크 캐시 실패 등
    func loadImage(_ request: ImageRequest) async throws -> UIImage
}
