//
//  UIViewController+SwiftUI.swift
//  SampleListApp
//
//  Created by 김동현 on 4/15/26.
//

import SwiftUI
import UIKit

extension UIViewController {
    func toSwiftUI() -> some View {
        UIViewControllerContainer {
            self
        }
    }
}

private struct UIViewControllerContainer<ViewController: UIViewController>: UIViewControllerRepresentable {
    let makeViewController: () -> ViewController
    
    func makeUIViewController(context: Context) -> ViewController {
        makeViewController()
    }
    
    func updateUIViewController(
        _ uiViewController: ViewController,
        context: Context
    ) {
    }
}
