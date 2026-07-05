//
//  ConnectionManagerView.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import Combine
import SwiftUI

struct ConnectionManagerView: View {
    @Binding var isPresented: Bool
    @ObservedObject var appState: AppState
    @ObservedObject var connectionManager = ConnectionManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingAddSheet = false
    @State private var editingConnection: Connection?

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    closeModal()
                }
                .transition(.opacity)

            // Modal Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Network Connections")
                        .font(.headline)
                        .foregroundColor(themeManager.current.textPrimary)
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(themeManager.current.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add Connection")

                    Button(action: { closeModal() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.current.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                .padding()
                .background(themeManager.current.backgroundSecondary)

                Divider()
                    .background(themeManager.current.borderLight)

                // List
                List {
                    ForEach(connectionManager.connections) { connection in
                        ConnectionRow(connection: connection) {
                            if let url = connectionManager.connect(connection) {
                                closeModal()
                                appState.currentPane.activeTab.currentPath = url
                                Task { @MainActor in
                                    // Refresh drives and auto-select the mounted drive
                                    await appState.refreshDrivesAndSelectMatchingDrive()
                                    await appState.refreshCurrentPane()
                                }
                            }
                        } onEdit: {
                            editingConnection = connection
                        } onDelete: {
                            connectionManager.deleteConnection(connection)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(themeManager.current.background)

                if connectionManager.connections.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "network")
                            .font(.system(size: 40))
                            .foregroundColor(themeManager.current.textTertiary)
                        Text("No Saved Connections")
                            .foregroundColor(themeManager.current.textSecondary)
                        Button("Add Connection") {
                            showingAddSheet = true
                        }
                        .foregroundColor(themeManager.current.accent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 400, height: 500)
            .background(themeManager.current.background)
            .cornerRadius(12)
            .shadow(radius: 20)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
            .sheet(isPresented: $showingAddSheet) {
                ConnectionEditView(connection: .empty, isNew: true) { newConnection in
                    connectionManager.saveConnection(newConnection)
                    showingAddSheet = false
                }
            }
            .sheet(item: $editingConnection) { connection in
                ConnectionEditView(connection: connection, isNew: false) { updatedConnection in
                    connectionManager.saveConnection(updatedConnection)
                    editingConnection = nil
                }
            }
        }
        .animation(
            .easeInOut(duration: 0.2),
            value: isPresented
        )
        // Handle Esc key to close
        .background(
            Button("") {
                closeModal()
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
        )
        .onAppear {
            appState.enterMode(.modal)
        }
    }

    private func closeModal() {
        isPresented = false
        appState.exitMode()
    }
}

struct ConnectionRow: View {
    let connection: Connection
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title2)
                .frame(width: 30)
                .foregroundColor(themeManager.current.accent)

            VStack(alignment: .leading) {
                Text(connection.name.isEmpty ? connection.host : connection.name)
                    .font(.headline)
                    .foregroundColor(themeManager.current.textPrimary)
                Text("\(connection.protocolType.displayName) • \(connection.username.isEmpty ? "Anonymous" : connection.username)@\(connection.host)")
                    .font(.caption)
                    .foregroundColor(themeManager.current.textSecondary)
            }

            Spacer()

            Button("Connect") {
                onConnect()
            }
            .buttonStyle(.borderedProminent)

            Menu {
                Button("Edit") { onEdit() }
                Button("Delete", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(themeManager.current.textSecondary)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 20)
        }
        .padding(.vertical, 4)
    }

    var iconName: String {
        switch connection.protocolType {
        case .ftp, .sftp: "server.rack"
        case .smb: "externaldrive.connected.to.line.below"
        }
    }
}

struct ConnectionEditView: View {
    @State var connection: Connection
    let isNew: Bool
    let onSave: (Connection) -> Void
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Form {
            Section(header: Text("Connection Details")
                .foregroundColor(themeManager.current.textSecondary))
            {
                TextField("Name (Optional)", text: $connection.name)

                Picker("Protocol", selection: $connection.protocolType) {
                    ForEach(ConnectionProtocol.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                TextField("Host", text: $connection.host)
                TextField("Port", text: $connection.port)
                    .onChange(of: connection.protocolType) { _, newValue in
                        if connection.port.isEmpty {
                            switch newValue {
                            case .ftp: connection.port = "21"
                            case .sftp: connection.port = "22"
                            case .smb: connection.port = "445"
                            }
                        }
                    }

                TextField("Username", text: $connection.username)
                SecureField("Password", text: $connection.password)
                TextField("Path", text: $connection.path)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeManager.current.textSecondary)
                Button("Save") {
                    onSave(connection)
                }
                .disabled(connection.host.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top)
        }
        .scrollContentBackground(.hidden)
        .background(themeManager.current.background)
        .padding()
        .frame(width: 350)
        .onAppear {
            if isNew, connection.port.isEmpty {
                // Set default port
                connection.port = "445" // SMB default
            }
        }
    }
}
