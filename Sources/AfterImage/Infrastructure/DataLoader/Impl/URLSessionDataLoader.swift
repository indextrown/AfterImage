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
    
    public init(session: URLSession = .shared) {
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
    
    
    
}
