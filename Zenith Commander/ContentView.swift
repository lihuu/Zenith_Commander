//
//  ContentView.swift
//  Zenith Commander
//
//  Created by Hu Li on 11/27/25.
//

import SwiftUI

// This file is kept for compatibility
// The main view is now in MainView.swift

struct ContentView: View {
    var body: some View {
        MainView()
    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
        .environmentObject(AppState())
}
