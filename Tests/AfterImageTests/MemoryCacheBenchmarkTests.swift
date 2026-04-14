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
    private let iterationCount = 5

    @Test("LRUMemoryCache와 NSCache 삽입/조회 성능을 비교한다")
    func compareLRUMemoryCacheAndNSCachePerformance() {
        let stringKeys = (0..<operationCount).map { "key-\($0)" }
        let stringValues = (0..<operationCount).map { "value-\($0)" }
        let nsKeys = stringKeys.map(NSString.init(string:))
        let nsValues = stringValues.map(NSString.init(string:))

        let lruInsert = measureRepeated("LRUMemoryCache insert") {
            let cache = LRUMemoryCache<String, String>(
                countLimit: operationCount,
                totalCostLimit: operationCount
            )

            for index in 0..<operationCount {
                cache.insert(
                    value: stringValues[index],
                    key: stringKeys[index],
                    cost: 1
                )
            }

            return operationCount
        }

        let nsInsert = measureRepeated("NSCache insert") {
            let cache = NSCache<NSString, NSString>()
            cache.countLimit = operationCount
            cache.totalCostLimit = operationCount

            for index in 0..<operationCount {
                cache.setObject(
                    nsValues[index],
                    forKey: nsKeys[index],
                    cost: 1
                )
            }

            return operationCount
        }

        var lruHitCount = 0
        let lruLookup = measureRepeated("LRUMemoryCache lookup") {
            let cache = LRUMemoryCache<String, String>(
                countLimit: operationCount,
                totalCostLimit: operationCount
            )

            for index in 0..<operationCount {
                cache.insert(
                    value: stringValues[index],
                    key: stringKeys[index],
                    cost: 1
                )
            }

            var hitCount = 0
            for key in stringKeys {
                if cache.value(key: key) != nil {
                    hitCount += 1
                }
            }

            lruHitCount = hitCount
            return operationCount
        }

        var nsHitCount = 0
        let nsLookup = measureRepeated("NSCache lookup") {
            let cache = NSCache<NSString, NSString>()
            cache.countLimit = operationCount
            cache.totalCostLimit = operationCount

            for index in 0..<operationCount {
                cache.setObject(
                    nsValues[index],
                    forKey: nsKeys[index],
                    cost: 1
                )
            }

            var hitCount = 0
            for key in nsKeys {
                if cache.object(forKey: key) != nil {
                    hitCount += 1
                }
            }

            nsHitCount = hitCount
            return operationCount
        }

        printBenchmarkResults([
            lruInsert,
            nsInsert,
            lruLookup,
            nsLookup
        ])

        #expect(lruHitCount == operationCount)

        // NSCache는 메모리 압박 시 예고 없이 항목 제거 가능 → 성능 지표로만 사용
        #expect(nsHitCount > 0)
    }
}

private extension MemoryCacheBenchmarkTests {
    struct BenchmarkResult {
        let name: String
        let samples: [UInt64]
        let operationCount: Int

        var medianNanoseconds: UInt64 {
            let sorted = samples.sorted()
            return sorted[sorted.count / 2]
        }

        var medianMilliseconds: Double {
            Double(medianNanoseconds) / 1_000_000
        }

        var medianNanosecondsPerOperation: Double {
            Double(medianNanoseconds) / Double(operationCount)
        }
    }

    func measureRepeated(
        _ name: String,
        operation: () -> Int
    ) -> BenchmarkResult {
        // Warm-up
        _ = operation()

        var samples: [UInt64] = []
        samples.reserveCapacity(iterationCount)

        var measuredOperationCount = 0

        for _ in 0..<iterationCount {
            let start = DispatchTime.now().uptimeNanoseconds
            measuredOperationCount = operation()
            let end = DispatchTime.now().uptimeNanoseconds
            samples.append(end - start)
        }

        return BenchmarkResult(
            name: name,
            samples: samples,
            operationCount: measuredOperationCount
        )
    }

    func printBenchmarkResults(_ results: [BenchmarkResult]) {
        print("\nMemory cache benchmark")
        print("operations: \(operationCount)")
        print("iterations: \(iterationCount) (warm-up: 1)")

        for result in results {
            let milliseconds = String(format: "%.3f", result.medianMilliseconds)
            let nanosecondsPerOperation = String(format: "%.1f", result.medianNanosecondsPerOperation)
            print("- \(result.name): median \(milliseconds) ms, \(nanosecondsPerOperation) ns/op")
        }
    }
}

/*
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
        
        // NSCache는 메모리 압박 시 예고 없이 항목 제거 가능 → 성능 지표로만 사용
        // #expect(nsHitCount == operationCount)
        #expect(nsHitCount > 0)
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
*/
