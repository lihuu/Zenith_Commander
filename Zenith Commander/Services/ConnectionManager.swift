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
    
    func connect(_ connection: Connection) {
        switch connection.protocolType {
        case .ftp, .smb:
            connectViaFinder(connection)
        case .sftp:
            connectViaTerminal(connection)
        }
    }
    
    private func connectViaFinder(_ connection: Connection) {
        guard let url = connection.url else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func connectViaTerminal(_ connection: Connection) {
        // Construct SSH command
        // ssh user@host -p port
        var args = ["ssh"]
        
        if !connection.port.isEmpty {
            args.append("-p")
            args.append(connection.port)
        }
        
        var destination = connection.host
        if !connection.username.isEmpty {
            destination = "\(connection.username)@\(connection.host)"
        }
        args.append(destination)
        
        let command = args.joined(separator: " ")
        
        // Use AppleScript to open Terminal and run command
        // This is a simple way to launch a new terminal window with the command
        let scriptSource = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error = error {
                Logger.fileSystem.error("Failed to launch Terminal via AppleScript: \(error)")
            }
        }
    }
}
