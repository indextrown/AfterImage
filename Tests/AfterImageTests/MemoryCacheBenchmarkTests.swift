//
//  MemoryCacheBenchmarkTests.swift
//  AfterImage
//
//  Created by 김동현 on 4/14/26.
//

import Foundation
import Testing
@testable import AfterImage

struct MemoryCacheBenchmarkTests {
    private let operationCount = 50_000

    @Test("LRUMemoryCache와 NSCache 삽입/조회 성능을 비교한다")
    func compareLRUMemoryCacheAndNSCachePerformance() {
        let stringKeys = (0..<operationCount).map { "key-\($0)" }
        let stringValues = (0..<operationCount).map { "value-\($0)" }
        let nsKeys = stringKeys.map(NSString.init(string:))
        let nsValues = stringValues.map(NSString.init(string:))

        let lruCache = LRUMemoryCache<String, String>(
            countLimit: operationCount,
            totalCostLimit: operationCount
        )

        let nsCache = NSCache<NSString, NSString>()
        nsCache.countLimit = operationCount
        nsCache.totalCostLimit = operationCount

        let lruInsert = measure("LRUMemoryCache insert") {
            for index in 0..<operationCount {
                lruCache.insert(
                    value: stringValues[index],
                    key: stringKeys[index],
                    cost: 1
                )
            }
        }

        let nsInsert = measure("NSCache insert") {
            for index in 0..<operationCount {
                nsCache.setObject(
                    nsValues[index],
                    forKey: nsKeys[index],
                    cost: 1
                )
            }
        }

        var lruHitCount = 0
        let lruLookup = measure("LRUMemoryCache lookup") {
            for key in stringKeys {
                if lruCache.value(key: key) != nil {
                    lruHitCount += 1
                }
            }
        }

        var nsHitCount = 0
        let nsLookup = measure("NSCache lookup") {
            for key in nsKeys {
                if nsCache.object(forKey: key) != nil {
                    nsHitCount += 1
                }
            }
        }

        printBenchmarkResults([
            lruInsert,
            nsInsert,
            lruLookup,
            nsLookup
        ])

        #expect(lruHitCount == operationCount)
        #expect(nsHitCount == operationCount)
    }
}

private extension MemoryCacheBenchmarkTests {
    struct BenchmarkResult {
        let name: String
        let elapsedNanoseconds: UInt64
        let operationCount: Int

        var elapsedMilliseconds: Double {
            Double(elapsedNanoseconds) / 1_000_000
        }

        var nanosecondsPerOperation: Double {
            Double(elapsedNanoseconds) / Double(operationCount)
        }
    }

    func measure(
        _ name: String,
        operation: () -> Void
    ) -> BenchmarkResult {
        let start = DispatchTime.now().uptimeNanoseconds
        operation()
        let end = DispatchTime.now().uptimeNanoseconds

        return BenchmarkResult(
            name: name,
            elapsedNanoseconds: end - start,
            operationCount: operationCount
        )
    }

    func printBenchmarkResults(_ results: [BenchmarkResult]) {
        print("\nMemory cache benchmark")
        print("operations: \(operationCount)")

        for result in results {
            let milliseconds = String(format: "%.3f", result.elapsedMilliseconds)
            let nanosecondsPerOperation = String(format: "%.1f", result.nanosecondsPerOperation)
            print("- \(result.name): \(milliseconds) ms, \(nanosecondsPerOperation) ns/op")
        }
    }
}
