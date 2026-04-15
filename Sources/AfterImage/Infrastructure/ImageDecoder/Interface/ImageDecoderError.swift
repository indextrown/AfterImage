//
//  ImageDecoderError.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Foundation

public enum ImageDecoderError: Error, Equatable, Sendable {
    
    /// 전달된 `Data`로 이미지 소스를 만들 수 없는 경우입니다.
    case invalidImageData
    
    /// 이미지 소스에서 이미지 속성을 읽을 수 없는 경우입니다.
    case imagePropertiesUnavailable
    
    /// 이미지의 픽셀 크기를 확인할 수 없는 경우입니다.
    case imageSizeUnavailable
    
    /// 최종 `CGImage` 또는 `UIImage` 생성에 실패한 경우입니다.
    case decodingFailed
}
