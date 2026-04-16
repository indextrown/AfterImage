//
//  ContentView.swift
//  SampleListApp
//
//  Created by 김동현 on 4/15/26.
//

import SwiftUI

struct ContentView: View {
    private let sections = ImageListSection.samples
    
    var body: some View {
        NavigationStack {
            List(sections) { section in
                NavigationLink {
                    ImageListViewController(section: section)
                        .toSwiftUI()
                        .ignoresSafeArea()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.headline)
                        
                        Text(section.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Sample List")
        }
    }
}

#Preview {
    ContentView()
}
