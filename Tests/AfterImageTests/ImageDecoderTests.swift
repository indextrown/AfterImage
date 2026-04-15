//
//  ImageDecoderTests.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Testing
import UIKit
@testable import AfterImage

struct ImageDecoderTests {
    @Test("유효한 이미지 data를 UIImage로 디코딩한다")
    func decodesValidImageData() throws {
        let decoder = ImageDecoder()
        let originalImage = makeImage(size: CGSize(width: 20, height: 10), scale: 1)
        let data = try #require(originalImage.pngData())

        let decodedImage = try decoder.decode(
            data,
            targetSize: nil,
            scale: 1
        )

        #expect(decodedImage.cgImage != nil)
        #expect(decodedImage.size.width > 0)
        #expect(decodedImage.size.height > 0)
    }

    @Test("유효하지 않은 data는 invalidImageData를 던진다")
    func throwsInvalidImageDataForInvalidData() {
        let decoder = ImageDecoder()
        let invalidData = Data("not-an-image".utf8)

        #expect(throws: ImageDecoderError.invalidImageData) {
            try decoder.decode(
                invalidData,
                targetSize: nil,
                scale: 1
            )
        }
    }

    @Test("targetSize가 있으면 downsampling된 이미지를 반환한다")
    func downsampledImageDoesNotExceedTargetPixelSize() throws {
        let decoder = ImageDecoder()
        let originalImage = makeImage(size: CGSize(width: 1000, height: 500), scale: 1)
        let data = try #require(originalImage.pngData())

        let decodedImage = try decoder.decode(
            data,
            targetSize: CGSize(width: 100, height: 100),
            scale: 2
        )

        let cgImage = try #require(decodedImage.cgImage)
        let maxPixelSize = max(cgImage.width, cgImage.height)

        #expect(maxPixelSize <= 200)
    }

    @Test("downsampling 결과 UIImage는 요청 scale을 가진다")
    func downsampledImageUsesRequestedScale() throws {
        let decoder = ImageDecoder()
        let originalImage = makeImage(size: CGSize(width: 300, height: 300), scale: 1)
        let data = try #require(originalImage.pngData())

        let decodedImage = try decoder.decode(
            data,
            targetSize: CGSize(width: 50, height: 50),
            scale: 3
        )

        #expect(decodedImage.scale == 3)
    }
}

private extension ImageDecoderTests {
    func makeImage(
        size: CGSize,
        scale: CGFloat
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(
            size: size,
            format: format
        )

        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
