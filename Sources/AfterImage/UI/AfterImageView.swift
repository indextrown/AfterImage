//
//  AfterImageView.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import SwiftUI

/// SwiftUI에서 AfterImage 파이프라인을 사용해 원격 이미지를 표시하는 View입니다.
public struct AfterImageView<
    Content: View,
    Placeholder: View,
    Failure: View
>: View {
    
    private let request: ImageRequest
    private let afterImage: AfterImage
    private let content: (SwiftUI.Image) -> Content
    private let placeholder: () -> Placeholder
    private let failure: (Error) -> Failure
    
    @State private var state: ImageLoadingState = .idle
    @State private var task: Task<Void, Never>?
    
    public init(
        request: ImageRequest,
        afterImage: AfterImage = .shared,
        @ViewBuilder content: @escaping (SwiftUI.Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping (Error) -> Failure
    ) {
        self.request = request
        self.afterImage = afterImage
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }
    
    public init(
        url: URL,
        targetSize: CGSize? = nil,
        scale: CGFloat = 1,
        cachePolicy: CachePolicy = .useCache,
        processors: [any ImageProcessor] = [],
        afterImage: AfterImage = .shared,
        @ViewBuilder content: @escaping (SwiftUI.Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping (Error) -> Failure
    ) {
        let request = ImageRequest(
            url: url,
            targetSize: targetSize,
            scale: scale,
            cachePolicy: cachePolicy,
            processors: processors
        )
        
        self.init(
            request: request,
            afterImage: afterImage,
            content: content,
            placeholder: placeholder,
            failure: failure
        )
    }
    
    public var body: some View {
        renderedContent
            .onAppear {
                loadIfNeeded()
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
    }
    
    @ViewBuilder
    private var renderedContent: some View {
        switch state {
        case .idle, .loading:
            placeholder()
            
        case .success(let uiImage):
            content(SwiftUI.Image(uiImage: uiImage))
            
        case .failure(let error):
            failure(error)
        }
    }
    
    private func loadIfNeeded() {
        guard task == nil else { return }
        
        state = .loading
        
        task = Task {
            do {
                let image = try await afterImage.image(for: request)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    state = .success(image)
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    state = .failure(error)
                }
            }
        }
    }
}
