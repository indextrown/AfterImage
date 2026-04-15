//
//  File.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Foundation

/// `URLSession`을 사용해 이미지 원본 데이터를 로드하는 기본 구현체입니다.
public struct URLSessionDataLoader: DataLoaderType {
    
    private let session: URLSession
    
    public init(session: URLSession = URLSessionDataLoader.makeDefaultSession()) {
        self.session = session
    }
    
    public func data(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataLoaderError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DataLoaderError.invalidStatusCode(httpResponse.statusCode)
        }
        
        return data
    }
    
    /// 기본 `URLSession`을 생성합니다.
    ///
    /// 이 세션은 라이브러리 외부의 HTTP 캐시(`URLCache`)나 시스템 기본 캐시 정책에
    /// 영향을 받지 않도록, **완전히 비캐시(non-caching) 환경**으로 구성됩니다.
    ///
    /// - Important:
    ///   - `URLSession.shared`를 사용할 경우, 시스템 전역 `URLCache`가 활성화되어
    ///     HTTP 응답이 자동으로 캐시되고 재사용될 수 있습니다.
    ///   - 이는 라이브러리에서 설계한 캐시 흐름
    ///     (`memory → disk → network → cache write`)을 우회할 수 있으므로,
    ///     기본 세션은 명시적으로 캐시를 비활성화합니다.
    ///
    /// - Returns: 캐시를 사용하지 않는 `URLSession` 인스턴스
    ///
    /// - Note:
    ///   - `.ephemeral`:
    ///     디스크에 캐시, 쿠키, 자격 증명 등을 저장하지 않는 임시 세션입니다.
    ///   - `requestCachePolicy = .reloadIgnoringLocalCacheData`:
    ///     로컬 캐시가 존재하더라도 이를 사용하지 않고 항상 네트워크 요청을 수행합니다.
    ///   - `urlCache = nil`:
    ///     `URLCache` 자체를 제거하여, 응답이 저장되거나 재사용되지 않도록 합니다.
    ///
    /// - Discussion:
    ///   이 설정을 통해 `URLSession`은 순수한 네트워크 계층으로만 동작하며,
    ///   모든 캐시 전략은 라이브러리 내부(`MemoryCache`, `DiskCache`)에서
    ///   일관되게 제어할 수 있습니다.
    ///
    /// - Example:
    /// ```swift
    /// let loader = URLSessionDataLoader()
    /// // 내부적으로 캐시를 사용하지 않는 session이 생성됨
    /// ```
    public static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }
    
}
