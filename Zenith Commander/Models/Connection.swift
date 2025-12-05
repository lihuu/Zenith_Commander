//
//  Connection.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import Foundation

enum ConnectionProtocol: String, Codable, CaseIterable, Identifiable {
    case ftp
    case sftp
    case smb

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ftp: return "FTP"
        case .sftp: return "SFTP (SSH)"
        case .smb: return "SMB"
        }
    }
    
    var scheme: String {
        switch self {
        case .ftp: return "ftp"
        case .sftp: return "sftp"
        case .smb: return "smb"
        }
    }
}

struct Connection: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var protocolType: ConnectionProtocol
    var host: String
    var port: String
    var username: String
    var path: String
    
    var url: URL? {
        var components = URLComponents()
        components.scheme = protocolType.scheme
        components.host = host
        
        if let portInt = Int(port) {
            components.port = portInt
        }
        
        if !username.isEmpty {
            components.user = username
        }
        
        if !path.isEmpty {
            // Ensure path starts with /
            components.path = path.hasPrefix("/") ? path : "/" + path
        }
        
        return components.url
    }
    
    static var empty: Connection {
        Connection(
            name: "",
            protocolType: .smb,
            host: "",
            port: "",
            username: "",
            path: ""
        )
    }
}
