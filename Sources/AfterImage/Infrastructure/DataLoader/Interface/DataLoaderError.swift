//
//  DataLoaderError.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Foundation

/// 데이터 로딩 과정에서 발생할 수 있는 에러입니다.
public enum DataLoaderError: Error, Equatable, Sendable {
    /// HTTP 응답이 아닌 응답을 받은 경우
    case invalidResponse
    
    /// 2xx 범위가 아닌 HTTP status code를 받은 경우
    case invalidStatusCode(Int)
}
