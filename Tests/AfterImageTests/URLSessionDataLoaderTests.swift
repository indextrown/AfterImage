//
//  URLSessionDataLoaderTests.swift
//  AfterImage
//
//  Created by 김동현 on 4/15/26.
//

import Foundation
import Testing
@testable import AfterImage

/**
 URLSession.data(from:)
     ↓
 MockURLProtocol.startLoading()
     ↓
 requestHandler 실행
     ↓
 (data, response, error) 반환
 */
@Suite(.serialized)
struct URLSessionDataLoaderTests {

    @Test("2xx 응답이면 데이터를 반환한다")
    func returnsDataWhenResponseIsSuccessful() async throws {
        let expectedData = Data("hello".utf8)
        let url = URL(string: "https://example.com/image.jpg")!

        let session = makeSession(
            data: expectedData,
            response: HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        let loader = URLSessionDataLoader(session: session)

        let data = try await loader.data(url: url)

        #expect(data == expectedData)
    }

    @Test("HTTP 응답이 아니면 invalidResponse 에러를 던진다")
    func throwsInvalidResponseWhenResponseIsNotHTTP() async throws {
        let url = URL(string: "https://example.com/image.jpg")!
        let response = URLResponse(
            url: url,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )

        let session = makeSession(
            data: Data(),
            response: response,
            error: nil
        )

        let loader = URLSessionDataLoader(session: session)

        await #expect(throws: DataLoaderError.invalidResponse) {
            try await loader.data(url: url)
        }
    }

    @Test("2xx 범위가 아니면 invalidStatusCode 에러를 던진다")
    func throwsInvalidStatusCodeWhenStatusCodeIsNotSuccessful() async throws {
        let url = URL(string: "https://example.com/image.jpg")!

        let session = makeSession(
            data: Data(),
            response: HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        let loader = URLSessionDataLoader(session: session)

        await #expect(throws: DataLoaderError.invalidStatusCode(404)) {
            try await loader.data(url: url)
        }
    }

    @Test("URLSession 자체 에러는 그대로 전달된다")
    func rethrowsSessionError() async throws {
        let url = URL(string: "https://example.com/image.jpg")!
        let expectedError = URLError(.notConnectedToInternet)

        let session = makeSession(
            data: nil,
            response: nil,
            error: expectedError
        )

        let loader = URLSessionDataLoader(session: session)

        do {
            _ = try await loader.data(url: url)
            #expect(Bool(false), "Expected URLError.notConnectedToInternet")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            #expect(Bool(false), "Expected URLError, but received \(error)")
        }
    }
}

/// 테스트용 `URLSession`을 생성하는 헬퍼 함수입니다.
///
/// 실제 네트워크 요청을 보내지 않고, `MockURLProtocol`을 통해
/// 미리 정의한 응답(`data`, `response`, `error`)을 반환하도록 설정합니다.
///
/// - Parameters:
///   - data: 요청 성공 시 반환할 데이터 (ex. 이미지 데이터)
///   - response: URL 응답 객체 (HTTPURLResponse 또는 URLResponse)
///   - error: 네트워크 에러를 시뮬레이션할 경우 전달할 에러
///
/// - Returns: `MockURLProtocol`이 주입된 `URLSession`
///
/// - Note:
///   - 이 함수는 테스트에서 네트워크 결과를 완전히 통제하기 위해 사용됩니다.
///   - `URLSessionConfiguration.protocolClasses`에 `MockURLProtocol`을 등록함으로써,
///     실제 네트워크 대신 가짜 응답을 반환하게 됩니다.
///   - 동일 테스트 내에서는 `MockURLProtocol.requestHandler`가 전역(static)으로 공유되므로
///     테스트 간 상태 오염에 주의해야 합니다.
///
/// - Example:
/// ```swift
/// let session = makeSession(
///     data: Data("hello".utf8),
///     response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
///     error: nil
/// )
/// ```
private func makeSession(
    data: Data?,
    response: URLResponse?,
    error: Error?
) -> URLSession {
    // MockURLProtocol이 요청을 가로챘을 때 어떤 값을 반환할지 정의
    MockURLProtocol.requestHandler = { _ in
        (data, response, error)
    }

    // 네트워크 캐시, 쿠키 등을 최소화한 테스트 전용 설정
    let configuration = URLSessionConfiguration.ephemeral

    // 핵심: URLSession이 실제 네트워크 대신 MockURLProtocol을 사용하도록 지정
    configuration.protocolClasses = [MockURLProtocol.self]

    return URLSession(configuration: configuration)
}

/// `URLSession`의 네트워크 요청을 가로채기 위한 테스트용 `URLProtocol` 구현입니다.
///
/// 실제 네트워크 통신을 수행하지 않고,
/// 테스트에서 미리 정의한 응답을 반환하는 역할을 합니다.
///
/// - Important:
///   - `URLSessionConfiguration.protocolClasses`에 등록되어야 동작합니다.
///   - 이 클래스는 테스트 환경에서만 사용되어야 하며, 실제 앱 코드에서는 사용하지 않습니다.
///
/// - 동작 흐름:
///   1. `URLSession`이 요청을 생성
///   2. `MockURLProtocol`이 해당 요청을 가로챔
///   3. `requestHandler` 클로저를 실행하여 응답 생성
///   4. `URLProtocolClient`를 통해 `URLSession`에 응답 전달
final class MockURLProtocol: URLProtocol {

    /// 요청을 처리하는 클로저입니다.
    ///
    /// 테스트 코드에서 설정하며,
    /// 요청이 들어왔을 때 반환할 `(data, response, error)`를 정의합니다.
    ///
    /// - Note:
    ///   - `static`으로 선언되어 테스트 전역에서 공유됩니다.
    ///   - 여러 테스트에서 동시에 사용할 경우 값이 덮어써질 수 있습니다.
    static var requestHandler: (@Sendable (URLRequest) throws -> (Data?, URLResponse?, Error?))?

    /// 이 프로토콜이 주어진 요청을 처리할 수 있는지 여부를 반환합니다.
    ///
    /// - Returns: 항상 `true` → 모든 요청을 가로챔
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    /// 요청을 표준화된 형태로 반환합니다.
    ///
    /// - Note:
    ///   - 여기서는 별도 수정 없이 그대로 반환합니다.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    /// 요청이 시작될 때 호출됩니다.
    ///
    /// 여기서 실제 네트워크를 수행하지 않고,
    /// `requestHandler`를 통해 정의된 응답을 `URLSession`에 전달합니다.
    override func startLoading() {
        // handler가 설정되지 않은 경우 → 테스트 설정 오류
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        do {
            // 테스트에서 정의한 응답 획득
            let (data, response, error) = try handler(request)

            // 응답 객체 전달 (HTTPURLResponse 등)
            if let response {
                client?.urlProtocol(
                    self,
                    didReceive: response,
                    cacheStoragePolicy: .notAllowed
                )
            }

            // 데이터 전달
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }

            // 에러가 있다면 실패 처리
            if let error {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                // 정상적으로 끝났음을 알림
                client?.urlProtocolDidFinishLoading(self)
            }
        } catch {
            // handler 내부에서 throw된 경우
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    /// 요청 취소 시 호출됩니다.
    ///
    /// - Note:
    ///   - 테스트에서는 별도 정리 작업이 필요 없으므로 비워둡니다.
    override func stopLoading() { }
}
