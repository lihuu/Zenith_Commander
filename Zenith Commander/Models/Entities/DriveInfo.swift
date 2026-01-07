//
//  DriveInfo.swift
//  Zenith Commander
//
//  驱动器信息模型
//

import Foundation

/// 驱动器/卷信息
struct DriveInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: URL
    let type: DriveType
    let totalCapacity: Int64
    let availableCapacity: Int64

    var usedPercentage: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(totalCapacity - availableCapacity) / Double(totalCapacity)
            * 100
    }

    var formattedCapacity: String {
        let used = ByteCountFormatter.string(
            fromByteCount: totalCapacity - availableCapacity,
            countStyle: .file
        )
        let total = ByteCountFormatter.string(
            fromByteCount: totalCapacity,
            countStyle: .file
        )
        return "\(used) / \(total)"
    }

    var iconName: String {
        switch type {
        case .system:
            "laptopcomputer"
        case .external:
            "externaldrive.fill"
        case .network:
            "network"
        case .removable:
            "externaldrive.badge.plus"
        }
    }
}

nonisolated enum DriveType: Sendable, Equatable {
    case system
    case external
    case network
    case removable
}
