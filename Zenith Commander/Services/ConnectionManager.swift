//
//  ConnectionManager.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import AppKit
import Foundation
import Combine
import os.log

class ConnectionManager: ObservableObject {
    static let shared = ConnectionManager()
    
    @Published var connections: [Connection] = []
    
    private let storageKey = "SavedConnections"
    
    private init() {
        loadConnections()
    }
    
    // MARK: - Storage
    
    func loadConnections() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                connections = try JSONDecoder().decode([Connection].self, from: data)
            } catch {
                Logger.fileSystem.error("Failed to load connections: \(error.localizedDescription)")
            }
        }
    }
    
    func saveConnection(_ connection: Connection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        persist()
    }
    
    func deleteConnection(_ connection: Connection) {
        connections.removeAll { $0.id == connection.id }
        persist()
    }
    
    private func persist() {
        do {
            let data = try JSONEncoder().encode(connections)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            Logger.fileSystem.error("Failed to save connections: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Connection Actions
    
    func connect(_ connection: Connection) -> URL? {
        switch connection.protocolType {
        case .ftp, .smb:
            connectViaFinder(connection)
            return nil
        case .sftp:
            return connection.url
        }
    }
    
    private func connectViaFinder(_ connection: Connection) {
        guard let url = connection.url else { return }
        NSWorkspace.shared.open(url)
    }
    
    // connectViaTerminal is removed as we now support native SFTP
}
