//
//  File.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Foundation

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
