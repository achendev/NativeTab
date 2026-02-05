import Foundation

struct SearchService {
    /// Generic Smart Search (AND-logic for includes, boolean exclusion)
    /// - Parameters:
    ///   - items: The list of items to filter.
    ///   - query: The user's search text.
    ///   - valueProvider: A closure that returns the string to match against for a given item.
    /// - Returns: Filtered list.
    static func smartFilter<T>(_ items: [T], query: String, valueProvider: (T) -> String) -> [T] {
        guard !query.isEmpty else { return items }
        
        // 1. Parse Query
        let terms = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let excludeTerms = terms.filter { $0.hasPrefix("-") && $0.count > 1 }.map { String($0.dropFirst()) }
        let includeTerms = terms.filter { !$0.hasPrefix("-") || $0.count == 1 }
        
        if includeTerms.isEmpty && excludeTerms.isEmpty { return items }
        
        // 2. Filter
        return items.filter { item in
            let content = valueProvider(item)
            
            // A. Must match ALL inclusion terms (AND logic)
            if !includeTerms.isEmpty {
                let matchesAll = includeTerms.allSatisfy { term in
                    content.localizedCaseInsensitiveContains(term)
                }
                if !matchesAll { return false }
            }
            
            // B. Must NOT match ANY exclusion terms
            if !excludeTerms.isEmpty {
                let matchesExclude = excludeTerms.contains { term in
                    content.localizedCaseInsensitiveContains(term)
                }
                if matchesExclude { return false }
            }
            
            return true
        }
    }
}
