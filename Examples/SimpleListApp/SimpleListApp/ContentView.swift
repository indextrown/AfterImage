//
//  ContentView.swift
//  SimpleListApp
//
//  Created by 김동현 on 4/15/26.
//

import AfterImage
import SwiftUI

struct ContentView: View {
    private let images = ImageItem.samples
    
    var body: some View {
        NavigationView {
            List(images) { item in
                ImageRow(item: item)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("Simple List")
        }
    }
}

private struct ImageRow: View {
    let item: ImageItem
    
    var body: some View {
        HStack(spacing: 14) {
            AfterImageView(
                url: item.url,
                targetSize: CGSize(width: 80, height: 80),
                scale: 2
            ) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                PlaceholderView()
            } failure: { _ in
                FailureView()
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

private struct PlaceholderView: View {
    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            ProgressView()
        }
    }
}

private struct FailureView: View {
    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            Image(systemName: "photo")
                .foregroundColor(.secondary)
        }
    }
}

private struct ImageItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let url: URL
    
    static let samples: [ImageItem] = [
        ImageItem(
            id: 1,
            title: "Mountain",
            subtitle: "Cached by app-level AfterImage",
            url: makeURL("https://picsum.photos/id/1018/600/600")
        ),
        ImageItem(
            id: 2,
            title: "River",
            subtitle: "Memory -> disk -> network",
            url: makeURL("https://picsum.photos/id/1015/600/600")
        ),
        ImageItem(
            id: 3,
            title: "Forest",
            subtitle: "Downsampled for the row size",
            url: makeURL("https://picsum.photos/id/1020/600/600")
        ),
        ImageItem(
            id: 4,
            title: "Sea",
            subtitle: "Same pipeline for each row",
            url: makeURL("https://picsum.photos/id/1011/600/600")
        ),
        ImageItem(
            id: 5,
            title: "Desert",
            subtitle: "Scroll and revisit to hit cache",
            url: makeURL("https://picsum.photos/id/1002/600/600")
        ),
        ImageItem(
            id: 6,
            title: "City",
            subtitle: "Simple SwiftUI integration",
            url: makeURL("https://picsum.photos/id/1031/600/600")
        )
    ]
    
    private static func makeURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid image URL: \(string)")
        }
        return url
    }
}

#Preview {
    ContentView()
}
