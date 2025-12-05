//
//  ConnectionManagerView.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import SwiftUI

struct ConnectionManagerView: View {
    @ObservedObject var connectionManager = ConnectionManager.shared
    @State private var showingAddSheet = false
    @State private var editingConnection: Connection?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Network Connections")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .help("Add Connection")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // List
            List {
                ForEach(connectionManager.connections) { connection in
                    ConnectionRow(connection: connection) {
                        connectionManager.connect(connection)
                    } onEdit: {
                        editingConnection = connection
                    } onDelete: {
                        connectionManager.deleteConnection(connection)
                    }
                }
            }
            .listStyle(PlainListStyle())
            
            if connectionManager.connections.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Saved Connections")
                        .foregroundColor(.secondary)
                    Button("Add Connection") {
                        showingAddSheet = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 400, height: 500)
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
}

struct ConnectionRow: View {
    let connection: Connection
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(connection.name.isEmpty ? connection.host : connection.name)
                    .font(.headline)
                Text("\(connection.protocolType.displayName) • \(connection.username.isEmpty ? "Anonymous" : connection.username)@\(connection.host)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 20)
        }
        .padding(.vertical, 4)
    }
    
    var iconName: String {
        switch connection.protocolType {
        case .ftp, .sftp: return "server.rack"
        case .smb: return "externaldrive.connected.to.line.below"
        }
    }
}

struct ConnectionEditView: View {
    @State var connection: Connection
    let isNew: Bool
    let onSave: (Connection) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section(header: Text("Connection Details")) {
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
                TextField("Path", text: $connection.path)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                Button("Save") {
                    onSave(connection)
                }
                .disabled(connection.host.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            if isNew && connection.port.isEmpty {
                // Set default port
                connection.port = "445" // SMB default
            }
        }
    }
}
