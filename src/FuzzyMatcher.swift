import Foundation

public struct FuzzyMatchResult: Identifiable {
    public var id: String { path }
    public let path: String
    public let score: Int
    public let matchedIndices: [Int]
}

public struct FuzzyMatcher {
    public static func match(query: String, candidates: [String]) -> [FuzzyMatchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces).lowercased()
        
        if trimmedQuery.isEmpty {
            return candidates.map { FuzzyMatchResult(path: $0, score: 0, matchedIndices: []) }
        }
        
        var results: [FuzzyMatchResult] = []
        
        for candidate in candidates {
            if let result = score(query: trimmedQuery, candidate: candidate) {
                results.append(result)
            }
        }
        
        return results.sorted { (a, b) -> Bool in
            if a.score != b.score {
                return a.score > b.score
            }
            if a.path.count != b.path.count {
                return a.path.count < b.path.count
            }
            return a.path < b.path
        }
    }
    
    private static func score(query: String, candidate: String) -> FuzzyMatchResult? {
        let candidateLower = candidate.lowercased()
        let queryChars = Array(query)
        let candChars = Array(candidateLower)
        let origChars = Array(candidate)
        
        var queryIdx = 0
        var candIdx = 0
        var matchedIndices: [Int] = []
        var score = 0
        var consecutiveCount = 0
        
        if let range = candidateLower.range(of: query) {
            let startPos = candidateLower.distance(from: candidateLower.startIndex, to: range.lowerBound)
            let endPos = startPos + query.count
            let indices = Array(startPos..<endPos)
            var subScore = 1000 + (100 / (startPos + 1))
            if endPos == candidate.count {
                subScore += 300
            }
            if startPos > 0 && candChars[startPos - 1] == "/" {
                subScore += 500
            }
            return FuzzyMatchResult(path: candidate, score: subScore, matchedIndices: indices)
        }
        
        while queryIdx < queryChars.count && candIdx < candChars.count {
            if queryChars[queryIdx] == candChars[candIdx] {
                matchedIndices.append(candIdx)
                
                var charScore = 10
                
                if consecutiveCount > 0 {
                    charScore += (consecutiveCount * 15)
                }
                consecutiveCount += 1
                
                if candIdx == 0 || candChars[candIdx - 1] == "/" || candChars[candIdx - 1] == "_" || candChars[candIdx - 1] == "-" {
                    charScore += 40
                }
                
                if origChars[candIdx].isUppercase {
                    charScore += 25
                }
                
                score += charScore
                queryIdx += 1
            } else {
                consecutiveCount = 0
            }
            candIdx += 1
        }
        
        if queryIdx == queryChars.count {
            score -= (candidate.count - query.count) * 2
            return FuzzyMatchResult(path: candidate, score: score, matchedIndices: matchedIndices)
        }
        
        return nil
    }
}
