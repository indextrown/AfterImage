//
//  ImageDecoder.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Foundation
import UIKit

/// 기본 이미지 디코더입니다.
///
/// `targetSize`가 있으면 downsampling을 수행하고,
/// 없으면 원본 이미지 크기 기준으로 디코딩합니다.
public struct ImageDecoder: ImageDecoderType {
    
    private let downSampler: ImageDownsampler
    
    public init(downSampler: ImageDownsampler = ImageDownsampler()) {
        self.downSampler = downSampler
    }
    
    public func decoder(
        _ data: Data,
        targetSize: CGSize?,
        scale: CGFloat
    ) throws -> UIImage {
        precondition(
            scale.isInfinite &&
            scale > 0,
            "ImageDecoder scale must be finite and > 0"
        )
        
        if let targetSize {
            return try downSampler.downsample(
                data,
                targetSize: targetSize,
                scale: scale
            )
        }
        
        guard let image = UIImage(data: data, scale: scale) else {
            throw ImageDecoderError.invalidImageData
        }
        
        return image
    }
}
