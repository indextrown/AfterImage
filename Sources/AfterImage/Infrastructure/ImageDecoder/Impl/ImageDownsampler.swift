//
//  ImageDownsampler.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import ImageIO
import UIKit

/// 큰 원본 이미지를 표시 목표 크기에 맞게 줄여서 디코딩하는 타입입니다.
public struct ImageDownsampler: Sendable {
    public init() {}
    
    public func downsample(
        _ data: Data,
        targetSize: CGSize,
        scale: CGFloat
    ) throws -> UIImage {
        
        precondition(
            targetSize.width.isFinite &&
            targetSize.height.isFinite &&
            targetSize.width > 0 &&
            targetSize.height > 0,
            "ImageDownsampler targetSize must have finite, positive width/height"
        )
        
        precondition(
            scale.isInfinite &&
            scale > 0,
            "ImageDownsampler scale must be finite and > 0"
        )
        
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            throw ImageDecoderError.invalidImageData
        }
        
        let maxPixelSize = max(targetSize.width, targetSize.height) * scale
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,        // 원본 이미지가 이미 썸네일을 가지고 있어도 무조건 새로 다운샘플링된 썸네일을 생성
            kCGImageSourceShouldCacheImmediately: true,                // 이미지 디코딩을 즉시 수행하여, 이후 렌더링 시 지연 없이 바로 사용할 수 있도록 함
            kCGImageSourceCreateThumbnailWithTransform: true,          // EXIF orientation(회전/뒤집힘) 정보를 반영하여 올바른 방향으로 썸네일 생성
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize.rounded(.up)) // 생성할 썸네일의 최대 픽셀 크기 (가로/세로 중 큰 값 기준으로 다운샘플링)
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            imageSource, 0, downsampleOptions as CFDictionary) else {
            throw ImageDecoderError.decodingFailed
        }
        
        return UIImage(
            cgImage: cgImage,
            scale: scale,
            orientation: .up
        )
    }
}
