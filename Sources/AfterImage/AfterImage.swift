// The Swift Programming Language
// https://docs.swift.org/swift-book

/**
 https://velog.io/@o_joon_/Swift-Image-caching이미지-캐싱
 https://dev-voo.tistory.com/49
 https://heidi-dev.tistory.com/54
 https://trumanfromkorea.tistory.com/84 // 다운샘플링
 https://xerathcoder.tistory.com/279
 https://applecider2020.tistory.com/54 // sha256
 https://kimsangjunzzang.tistory.com/104
 https://ios-development.tistory.com/715
 
 https://ios-adventure-with-aphelios.tistory.com/30
 https://velog.io/@o_joon_/Swift-Image-caching이미지-캐싱
 https://codeisfuture.tistory.com/121

 
 prefetch
 https://ios-development.tistory.com/715
 
 동시성
 https://ios-adventure-with-aphelios.tistory.com/30
 
 캐싱플로우
 https://ios-adventure-with-aphelios.tistory.com/30
 
 얕은복사
 https://heidi-dev.tistory.com/54
 
 제라스
 https://xerathcoder.tistory.com/279
 
 https://codeisfuture.tistory.com/121
 */

/*
 https://velog.io/@o_joon_/Swift-Image-caching이미지-캐싱
 https://dev-voo.tistory.com/49
 https://babbab2.tistory.com/164 // 클로저
 https://kimsangjunzzang.tistory.com/104
 
 2-Layer Cache 전략
 Memory Cache(1차 방어선) : 가장 빠른 RAM에서 먼저 찾아본다.
 Disk Cache(2차 방어선) : Memory에 없으면 디스크에서 찾아봅니다. 찾았다면, 다음 접근을 위해 Memory에도 올려놓습니다.
 Network(최후) : 둘다 없으면, 네트워크에서 다운로드하여 Memory와 Disk 양쪽에 모두 저장합니다.
 
 NSCache
 - 리소스가 부족할 때 제거될 수 있으며 임시로 키-값 쌍을 사용하는 변경 가능한 컬렉션
 - 캐시가 메모리를 너무 많이 사용하지 않도록 자동으로 캐시 제거
 
 let cache = NSCache<NSString, UIImage>()
 - String이 아닌 NSString이 쓰이는 이유
 - NSCache가 Objective-C 기반 클래스(NSObject)이기 때문에 swift와 objectivec의 호완성을 위해 NSString을 쓴다
 
 클로저
 - 기본적으로 파라미터로 받는 "클로저"는 함수 흐름을 탈출하지 못한다
 - escaping 키워드를 붙여주면 이 클로저는 함수 실행 흐름에 상관 없이 실행되는 클로저라고 알려주는 것이다
 - 함수 파라미터의 클로저가 옵셔널 타입인 경우 자동으로 escaping으로 동작한다
 */

import UIKit
import CryptoKit

// MARK: - Cacheable
protocol Cacheable {
    func convertToKey(url: URL) -> String
}

extension Cacheable {
    func convertToKey(url: URL) -> String {
        let string = url.absoluteString
        let hash = SHA256.hash(data: Data(string.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Cache Option
enum CacheOption {
    case onlyMemory
    case onlyDisk
    case both
    case nothing
}

// MARK: - DiskCache
class DiskCache: Cacheable {
    static let shared = DiskCache()
    private let fileManager = FileManager.default
    private init() {}
    
    /// 디스크 캐시에서 이미지 불러오기
    /// - Parameter url: 이미지 url
    /// - Returns: UIImage
    func loadImage(_ url: URL) -> UIImage? {
        if let filePath = checkPath(url), fileManager.fileExists(atPath: filePath) {
            return UIImage(contentsOfFile: filePath)
        }
        return nil
    }
    
    /// 디스크 캐시에 이미지 저장
    /// - Parameters:
    ///   - image: 장
    ///   - url: url
    ///   - option: 캐시 옵션 설정
    func saveImage(
        _ image: UIImage,
        _ url: URL,
        _ option: CacheOption
    ) {
        if option == .onlyMemory || option == .nothing {
            return
        }
        
        if let filePath = checkPath(url), !(fileManager.fileExists(atPath: filePath)) {
            if fileManager.createFile(
                atPath: filePath,
                contents: image.jpegData(compressionQuality: 1.0),
                attributes: nil
            ) {
                print("Save image to DiskCache")
            } else {
                print("Can't save image to Disk")
            }
        }
    }
    
    
    /// 디스크 특정 경로를 반환
    /// - Parameter url: url
    /// - Returns: 디스크 특정 경로
    func checkPath(_ url: URL) -> String? {
        let key = convertToKey(url: url)
        
        // 캐시 directory 경로 탐색
        let documentURL = try? fileManager.url(
            for: .cachesDirectory, // 캐시 잔용 directory 접근
            in: .userDomainMask,   // 현재 사용자 전용 directory 접근
            appropriateFor: nil,   // 반환되는 URL 결정(무시)
            create: true           // 지정한 경로에 directory가 없으면 생성 허용
        )
        
        // 원하는 파일의 최종 경로
        let fileURL = documentURL?.appendingPathComponent(key)
        
        return fileURL?.path
    }
}

// MARK: - MemoryCache
class MemoryCache: Cacheable {
    static let shared = MemoryCache()
    private let memoryCache = NSCache<NSString, UIImage>()
    private init() {}

    
    /// 이미지를 캐시에서 불러옵니다
    /// - Parameters:
    ///   - url: 이미지 url
    ///   - option: 캐시 옵션 설정
    ///   - completion: UIImage를 옵셔널로 반환
    func loadImage(
        _ url: URL?,
        _ option: CacheOption = .both,
        completion: @escaping (UIImage?) -> Void
    ) {
        /// memory -> disk -> url
        guard let url = url else {
            completion(nil)
            return
        }
        
        let key = convertToKey(url: url)
        
        /// key를 통해 메모리 캐시에 해당 이미지가 존재하면 이미지를 불러오고 종료
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            completion(cachedImage)
            return
        }
        
        /// 메모리 캐시에 존재하지 않는다면 디스크 캐시 체크
        DispatchQueue.global().async {
            if let cachedImage = DiskCache.shared.loadImage(url) {
                self.saveImage(cachedImage, url, option)
                completion(cachedImage)
                return
            }
            
            if let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                print("Download image from URL")
                self.saveImage(image, url, option)
                DiskCache.shared.saveImage(image, url, option)
                completion(image)
            } else {
                completion(nil)
                return
            }
        }
    }
    
    private func saveImage(
        _ image: UIImage,
        _ url: URL,
        _ option: CacheOption
    ) {
        // 옵션에 따라 캐싱 여부 결정
        if option == .onlyDisk || option == .nothing {
            return
        }
        
        // key를 통해 NSCache 객체에 이미지 저장
        let key = convertToKey(url: url) as NSString
        memoryCache.setObject(image, forKey: key)
        print("Save image to MemoryCache")
    }
}

