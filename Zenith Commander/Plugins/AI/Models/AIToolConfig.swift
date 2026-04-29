//
//  AIToolConfig.swift
//  Zenith Commander
//
//  Configurable AI tool definition
//

import Foundation

struct AIToolConfig: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var command: String
    var icon: String
    var enabled: Bool

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCommand.isEmpty ? id : trimmedCommand
    }

    var executableName: String? {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstSegment = trimmedCommand.split(separator: " ").first else {
            return nil
        }

        return String(firstSegment)
    }

    func matches(identifier: String) -> Bool {
        let normalizedIdentifier = identifier.normalizedAIToolIdentifier
        let candidates = [id, name, command, executableName ?? ""]
            .map(\.normalizedAIToolIdentifier)
        return candidates.contains(normalizedIdentifier)
    }

    static var defaultTools: [AIToolConfig] {
        [
            AIToolConfig(
                id: "gemini",
                name: "Gemini",
                command: "gemini",
                icon: "sparkles",
                enabled: true
            ),
            AIToolConfig(
                id: "claude",
                name: "Claude",
                command: "claude",
                icon: "brain.head.profile",
                enabled: true
            ),
        ]
    }

    static func makeCustom(index: Int) -> AIToolConfig {
        AIToolConfig(
            id: UUID().uuidString,
            name: LocalizationManager.shared.localized(.aiNewToolDefaultName, index),
            command: "",
            icon: "sparkles.rectangle.stack",
            enabled: true
        )
    }
}

extension String {
    fileprivate var normalizedAIToolIdentifier: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
