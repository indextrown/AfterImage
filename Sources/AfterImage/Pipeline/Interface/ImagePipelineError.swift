//
//  ImagePipelineError.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Foundation

/// 이미지 파이프라인 처리 중 발생할 수 있는 에러입니다.
public enum ImagePipelineError: Error, Equatable, Sendable {
    
    /// 캐시만 조회하는 정책에서 메모리/디스크 캐시에 모두 데이터가 없는 경우입니다.
    case cacheMiss
}
