//
//  File.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Foundation

/// 이미지 원본 데이터를 로드하는 네트워크 계층 인터페이스입니다.
///
/// `ImagePipeline`은 `URLSession`을 직접 알지 않고 이 프로토콜에만 의존합니다.
/// 이렇게 분리하면 테스트에서 mock loader를 주입하기 쉬워집니다.
public protocol DataLoaderType: Sendable {
    
    
    /// 주어진 URL에서 이미지 원본 데이터를 로드합니다.
    ///
    /// - Parameter url: 이미지 데이터. 요청 URL
    /// - Returns: 서버에서 받은 원본 `Data`
    /// - Throws: 네트워크 실패, 유효하지 않은 응답, HTTP 실패 상태 코드
    func data(url: URL) async throws -> Data
}
