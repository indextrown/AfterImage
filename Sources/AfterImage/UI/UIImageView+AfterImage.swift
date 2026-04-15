//
//  UIImageView+AfterImage.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import ObjectiveC
import UIKit

private var afterImageTaskKey: UInt8 = 0

public extension UIImageView {
    
    /// URL 기반으로 이미지를 비동기 로드해 `UIImageView`에 설정합니다.
    ///
    /// 기존에 진행 중인 AfterImage 로딩 작업이 있다면 먼저 취소합니다.
    /// `scale`을 직접 전달하지 않으면 현재 `UIImageView`가 속한 화면의 scale을 사용합니다.
    func setAfterImage(
        url: URL,
        placeholder: UIImage? = nil,
        targetSize: CGSize? = nil,
        scale: CGFloat? = nil,
        cachePolicy: CachePolicy = .useCache,
        processors: [any ImageProcessor] = [],
        afterImage: AfterImage = .shared
    ) {
        cancelAfterImageLoad()
        image = placeholder
        
        let task = Task { [weak self] in
            let resolvedScale = await MainActor.run {
                if let scale {
                    return scale
                }
                return self?.window?.screen.scale ?? UIScreen.main.scale
            }
            
            let request = ImageRequest(
                url: url,
                targetSize: targetSize,
                scale: resolvedScale,
                cachePolicy: cachePolicy,
                processors: processors
            )
            
            do {
                let loadedImage = try await afterImage.image(for: request)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.image = loadedImage
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.image = placeholder
                }
            }
        }
        
        afterImageTask = task
    }
    
    /// `ImageRequest` 기반으로 이미지를 비동기 로드해 `UIImageView`에 설정합니다.
    ///
    /// `ImageRequest`를 이미 구성한 경우 이 메서드를 사용하면 URL 편의 API보다
    /// 요청 의도가 더 명확합니다.
    func setAfterImage(
        request: ImageRequest,
        placeholder: UIImage? = nil,
        afterImage: AfterImage = .shared
    ) {
        cancelAfterImageLoad()
        image = placeholder
        
        let task = Task { [weak self] in
            do {
                let loadedImage = try await afterImage.image(for: request)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.image = loadedImage
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.image = placeholder
                }
            }
        }
        
        afterImageTask = task
    }
    
    /// 현재 `UIImageView`에서 진행 중인 AfterImage 로딩 작업을 취소합니다.
    ///
    /// `UITableViewCell` 또는 `UICollectionViewCell`의 `prepareForReuse()`에서 호출하면
    /// 재사용된 셀에 이전 요청의 이미지가 뒤늦게 들어가는 상황을 막을 수 있습니다.
    func cancelAfterImageLoad() {
        afterImageTask?.cancel()
        afterImageTask = nil
    }
}

private extension UIImageView {
    
    /// 현재 `UIImageView`에서 실행 중인 AfterImage 로딩 작업입니다.
    ///
    /// Swift extension은 저장 프로퍼티를 직접 추가할 수 없으므로,
    /// Objective-C runtime의 associated object를 사용해 `UIImageView` 인스턴스에
    /// `Task`를 붙여둡니다.
    ///
    /// 이 값을 저장해두면 `setAfterImage`가 다시 호출되거나 셀이 재사용될 때
    /// 이전 이미지 로딩 작업을 `cancelAfterImageLoad()`에서 취소할 수 있습니다.
    var afterImageTask: Task<Void, Never>? {
        get {
            // 현재 UIImageView(self)에 afterImageTaskKey로 연결된 Task를 꺼냅니다.
            objc_getAssociatedObject(
                self,
                &afterImageTaskKey
            ) as? Task<Void, Never>
        }
        set {
            // 현재 UIImageView(self)에 새 Task를 연결합니다.
            // retain 정책을 사용해 로딩이 끝나거나 취소될 때까지 Task가 유지되게 합니다.
            objc_setAssociatedObject(
                self,
                &afterImageTaskKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}
