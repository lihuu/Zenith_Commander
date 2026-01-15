//
//  FinderRequest.swift
//  Zenith Commander
//
//  Created by AI on 1/6/26.
//  Shared module for Finder Sync Extension and main App communication
//

import Foundation

// MARK: - FinderRequestAction

/// Actions that can be requested from Finder Sync Extension
enum FinderRequestAction: String, Codable {
    case copyPath
    case rename
    case ping
}

// MARK: - FinderRequest

/// A request from Finder Sync Extension to the main App
struct FinderRequest: Codable {
    let id: String
    let action: FinderRequestAction
    let paths: [String]
    let createdAt: String

    init(action: FinderRequestAction, paths: [String]) {
        self.id = UUID().uuidString
        self.action = action
        self.paths = paths

        let formatter = ISO8601DateFormatter()
        self.createdAt = formatter.string(from: Date())
    }
}

// MARK: - FinderRequestStore

/// Manages storing and retrieving requests via App Group shared UserDefaults
struct FinderRequestStore {
    /// App Group identifier - MUST match entitlements in both App and Extension
    static let suiteName = "group.com.lihuu.top.ZenithCommander"

    /// Key prefix for storing individual requests
    private static let requestPrefix = "finder_request_"

    /// Key for storing the latest request ID
    private static let latestKey = "finder_request_latest"

    /// Shared UserDefaults instance
    private static var shared: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Save

    /// Saves a request to App Group storage and returns its ID
    /// - Parameter request: The request to save
    /// - Returns: The request ID
    @discardableResult
    static func save(_ request: FinderRequest) -> String {
        guard let defaults = shared else {
            NSLog("[FinderRequestStore] ERROR: Failed to access App Group UserDefaults")
            return request.id
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(request)

            if let jsonString = String(data: data, encoding: .utf8) {
                let key = "\(requestPrefix)\(request.id)"
                defaults.set(jsonString, forKey: key)
                defaults.set(request.id, forKey: latestKey)
                defaults.synchronize()

                NSLog(
                    "[FinderRequestStore] Saved request: id=\(request.id), action=\(request.action.rawValue), paths=\(request.paths.count)"
                )
                return request.id
            }
        } catch {
            NSLog("[FinderRequestStore] ERROR: Failed to encode request: \(error)")
        }

        return request.id
    }

    // MARK: - Load

    /// Loads a request by ID
    /// - Parameter id: The request ID
    /// - Returns: The request if found and valid, nil otherwise
    static func load(id: String) -> FinderRequest? {
        guard let defaults = shared else {
            NSLog("[FinderRequestStore] ERROR: Failed to access App Group UserDefaults")
            return nil
        }

        let key = "\(requestPrefix)\(id)"
        guard let jsonString = defaults.string(forKey: key) else {
            NSLog("[FinderRequestStore] Request not found: \(id)")
            return nil
        }

        guard let data = jsonString.data(using: .utf8) else {
            NSLog("[FinderRequestStore] ERROR: Failed to convert JSON string to data")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let request = try decoder.decode(FinderRequest.self, from: data)
            NSLog(
                "[FinderRequestStore] Loaded request: id=\(request.id), action=\(request.action.rawValue), paths=\(request.paths.count)"
            )
            return request
        } catch {
            NSLog("[FinderRequestStore] ERROR: Failed to decode request: \(error)")
            return nil
        }
    }

    /// Loads the most recent request
    /// - Returns: The latest request if found and valid, nil otherwise
    static func loadLatest() -> FinderRequest? {
        guard let defaults = shared else {
            NSLog("[FinderRequestStore] ERROR: Failed to access App Group UserDefaults")
            return nil
        }

        guard let latestId = defaults.string(forKey: latestKey) else {
            NSLog("[FinderRequestStore] No latest request found")
            return nil
        }

        return load(id: latestId)
    }

    // MARK: - Delete

    /// Deletes a request by ID
    /// - Parameter id: The request ID to delete
    static func delete(id: String) {
        guard let defaults = shared else {
            NSLog("[FinderRequestStore] ERROR: Failed to access App Group UserDefaults")
            return
        }

        let key = "\(requestPrefix)\(id)"
        defaults.removeObject(forKey: key)

        // If this was the latest request, clear the latest key
        if let latestId = defaults.string(forKey: latestKey), latestId == id {
            defaults.removeObject(forKey: latestKey)
        }

        defaults.synchronize()
        NSLog("[FinderRequestStore] Deleted request: \(id)")
    }

    // MARK: - Debug

    /// Lists all stored request IDs (for debugging)
    static func listAllRequestIds() -> [String] {
        guard let defaults = shared else { return [] }

        let allKeys = defaults.dictionaryRepresentation().keys
        let requestKeys = allKeys.filter { $0.hasPrefix(requestPrefix) }
        let ids = requestKeys.map { $0.replacingOccurrences(of: requestPrefix, with: "") }

        NSLog("[FinderRequestStore] Found \(ids.count) stored requests")
        return ids
    }
}
