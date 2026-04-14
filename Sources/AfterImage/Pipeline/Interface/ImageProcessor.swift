//
//  File.swift
//  AfterImage
//
//  Created by 김동현 on 4/14/26.
//

import UIKit

/// 이미지를 후처리하는 단계를 정의하는 프로토콜입니다.
///
/// `ImageProcessor`는 다운로드되었거나 캐시에서 조회된 원본 이미지를
/// 원하는 형태로 가공할 때 사용됩니다.
/// 예를 들어 리사이즈, 크롭, 라운드 처리, 블러, 흑백 필터 같은 작업을
/// processor로 분리할 수 있습니다.
///
/// 같은 이미지 URL이라도 어떤 processor를 적용했는지에 따라
/// 최종 결과가 달라질 수 있으므로,
/// 각 processor는 자신을 구분할 수 있는 고유한 `identifier`를 제공해야 합니다.
///
/// 이 `identifier`는 캐시 키 생성에도 함께 사용되어,
/// 서로 다른 후처리 결과가 같은 캐시 항목으로 취급되지 않도록 합니다.
///
/// ## Example
/// ```swift
/// struct ThumbnailProcessor: ImageProcessor {
///     let size: CGSize
///
///     var identifier: String {
///         "thumbnail_\(Int(size.width))x\(Int(size.height))"
///     }
///
///     func process(_ image: UIImage) throws -> UIImage {
///         let renderer = UIGraphicsImageRenderer(size: size)
///         return renderer.image { _ in
///             image.draw(in: CGRect(origin: .zero, size: size))
///         }
///     }
/// }
/// ```
public protocol ImageProcessor: Sendable {
    
    /// 현재 processor를 고유하게 식별하는 문자열입니다.
    ///
    /// 같은 URL의 이미지라도 processor가 다르면 결과 이미지가 달라질 수 있으므로,
    /// 이 값은 캐시 키를 생성할 때 함께 사용됩니다.
    ///
    /// 예를 들어 동일한 원본 이미지에 대해
    /// `resize_100x100`, `round_12`, `grayscale` 같은 서로 다른 identifier를 사용하면,
    /// 각 후처리 결과를 별도의 캐시 항목으로 안전하게 구분할 수 있습니다.
    var identifier: String { get }
    
    /// 전달된 이미지를 가공하여 새로운 이미지를 반환합니다.
    ///
    /// 구현체는 입력 이미지를 원하는 방식으로 변환한 뒤 결과 이미지를 반환해야 합니다.
    /// 예를 들어 크기 조정, 잘라내기, 필터 적용, 모서리 둥글게 처리 등을 수행할 수 있습니다.
    ///
    /// - Parameter image: 후처리할 원본 이미지입니다.
    /// - Returns: 후처리가 적용된 새로운 이미지입니다.
    /// - Throws: 이미지 변환 과정에서 컨텍스트 생성 실패, 렌더링 실패 등
    ///   후처리를 완료할 수 없는 경우 에러를 던질 수 있습니다.
    func process(_ image: UIImage) throws -> UIImage
}
