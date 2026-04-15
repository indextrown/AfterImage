//
//  ContentView.swift
//  SampleApp
//
//  Created by 김동현 on 4/15/26.
//

import AfterImage
import SwiftUI

struct ContentView: View {
    private let images = SampleConfiguration.images
    
    @State private var cacheOnlyResult: String = "Load from network first"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    featuredImage
                    policyControls
                    imageList
                }
                .padding(20)
            }
            .navigationTitle("AfterImage")
        }
    }
    
    private var featuredImage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Request-aware loading")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Memory cache, disk cache, network, decode, and downsampling run through one pipeline.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            AfterImageView(
                url: SampleConfiguration.featuredImage.url,
                targetSize: SampleConfiguration.featuredTargetSize,
                scale: SampleConfiguration.displayScale
            ) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                PlaceholderView(title: "Loading image")
            } failure: { _ in
                PlaceholderView(title: "Failed to load")
            }
            .frame(height: 200)
            .clipped()
            .cornerRadius(8)
        }
    }
    
    private var policyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache policy")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button("Warm cache") {
                    warmCache()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cache only") {
                    loadCacheOnly()
                }
                .buttonStyle(.bordered)
            }
            
            Text(cacheOnlyResult)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var imageList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Variant keys")
                .font(.headline)
            
            Text("The same URL can create different cache entries when target size or processor settings change.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(images) { item in
                HStack(spacing: 12) {
                    AfterImageView(
                        url: item.url,
                        targetSize: SampleConfiguration.thumbnailTargetSize,
                        scale: SampleConfiguration.displayScale
                    ) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        PlaceholderView(title: "...")
                    } failure: { _ in
                        PlaceholderView(title: "!")
                    }
                    .frame(width: 84, height: 84)
                    .clipped()
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        
                        Text(item.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private func warmCache() {
        cacheOnlyResult = "Warming cache..."
        
        Task {
            do {
                _ = try await AfterImage.shared.image(
                    url: SampleConfiguration.cachePolicyImage.url,
                    targetSize: SampleConfiguration.cachePolicyTargetSize,
                    scale: SampleConfiguration.displayScale,
                    cachePolicy: .useCache
                )
                
                await MainActor.run {
                    cacheOnlyResult = "Cache warmed"
                }
            } catch {
                await MainActor.run {
                    cacheOnlyResult = "Warm failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loadCacheOnly() {
        cacheOnlyResult = "Reading cache only..."
        
        Task {
            do {
                _ = try await AfterImage.shared.image(
                    url: SampleConfiguration.cachePolicyImage.url,
                    targetSize: SampleConfiguration.cachePolicyTargetSize,
                    scale: SampleConfiguration.displayScale,
                    cachePolicy: .returnCacheDataDontLoad
                )
                
                await MainActor.run {
                    cacheOnlyResult = "Cache hit"
                }
            } catch {
                await MainActor.run {
                    cacheOnlyResult = "Cache miss"
                }
            }
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    
    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
