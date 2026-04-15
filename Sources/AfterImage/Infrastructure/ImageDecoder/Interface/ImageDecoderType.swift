//
//  ImageDecoderType.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import UIKit

/// 이미지 원본 `Data`를 화면에 표시 가능한 `UIImage`로 변환하는 인터페이스입니다.
public protocol ImageDecoderType: Sendable {
    
    /// 이미지 데이터를 디코딩합니다.
    ///
    /// - Parameters:
    ///   - data: 이미지 원본 데이터입니다.
    ///   - targetSize: 표시 목표 크기입니다, 'nil'이면 원본 크기로 디코딩합니다.
    ///   - scale: 디스플레이 scale입니다.
    /// - Returns: 디코딩된 `UIImage`
    /// - Throws: 이미지 소스 생성 실패, 디코딩 실패
    func decode(
        _ data: Data,
        targetSize: CGSize?,
        scale: CGFloat
    ) throws -> UIImage
}
