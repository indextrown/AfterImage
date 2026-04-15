//
//  ImageLoadingState.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import UIKit

/// UI 계층에서 이미지 로딩 상태를 표현하기 위한 상태 모델입니다.
public enum ImageLoadingState {
    
    /// 아직 로딩을 시작하지 않은 상태입니다.
    case idle
    
    /// 이미지 로딩이 진행 중인 상태입니다.
    case loading
    
    /// 이미지 로딩이 성공한 상태입니다.
    case success(UIImage)
    
    /// 이미지 로딩이 실패한 상태입니다.
    case failure(Error)
}
