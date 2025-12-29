//
//  FzfSearchSheetView.swift
//  Zenith Commander
//
//  Advanced search dialog for fzf fuzzy search
//

import SwiftUI

struct FzfSearchSheetView: View {
    let context: PluginContext
    @Environment(\.dismiss) private var dismiss

    @State private var searchPattern = ""
    @State private var recursive = true
    @State private var isSearching = false
    @State private var searchResults: [URL] = []
    @State private var errorMessage: String?
    @State private var searchProgress: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Search form
            searchFormView

            Divider()

            // Results or status
            if isSearching {
                progressView
            } else if let error = errorMessage {
                errorView(error)
            } else if !searchResults.isEmpty {
                resultsView
            } else {
                emptyView
            }

            Divider()

            // Actions
            actionsView
        }
        .frame(width: 500, height: 400)
        .background(Theme.background)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.accent)

            Text(LocalizationManager.shared.localized(.fzfSearchTitle))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Theme.backgroundSecondary)
    }

    // MARK: - Search Form

    private var searchFormView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pattern input
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizationManager.shared.localized(.fzfSearchPattern))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

                TextField("", text: $searchPattern)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
            }

            // Options
            HStack {
                Toggle(isOn: $recursive) {
                    Text(LocalizationManager.shared.localized(.fzfRecursive))
                        .font(.system(size: 12))
                }
                .toggleStyle(.checkbox)

                Spacer()

                // Current directory
                let panes = context.panes()
                let currentPath = panes.active == .left ? panes.leftPath : panes.rightPath
                Text(currentPath)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding()
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text(LocalizationManager.shared.localized(.fzfSearching))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)

            if !searchProgress.isEmpty {
                Text(searchProgress)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            Text(error)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(Theme.textTertiary)

            Text(LocalizationManager.shared.localized(.fzfEnterPattern))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(searchResults.count) \(LocalizationManager.shared.localized(.fzfResultsFound))")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal)
                .padding(.vertical, 4)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults, id: \.path) { url in
                        resultRow(url)

                        if url != searchResults.last {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    private func resultRow(_ url: URL) -> some View {
        HStack {
            Image(systemName: "doc")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)

            Text(url.lastPathComponent)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Spacer()

            Text(url.deletingLastPathComponent().path)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            navigateToResult(url)
        }
    }

    // MARK: - Actions

    private var actionsView: some View {
        HStack {
            if !searchResults.isEmpty {
                Button(LocalizationManager.shared.localized(.fzfShowInPane)) {
                    Task {
                        await showResultsInPane()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()

            Button(LocalizationManager.shared.localized(.cancel)) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button(LocalizationManager.shared.localized(.fzfSearch)) {
                performSearch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(searchPattern.isEmpty || isSearching)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchPattern.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        searchResults = []

        let panes = context.panes()
        let currentPath = panes.active == .left ? panes.leftPath : panes.rightPath
        let directory = URL(fileURLWithPath: currentPath)

        Task {
            do {
                let results = try await FzfService.shared.search(
                    pattern: searchPattern,
                    directory: directory,
                    recursive: recursive
                )

                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }

    private func navigateToResult(_ url: URL) {
        // Copy path to clipboard and show toast
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
        dismiss()
    }

    private func showResultsInPane() async {
        // Convert search results to FileItem array
        let fileItems = searchResults.compactMap { FileItem.fromURL($0) }

        // Dispatch action to update pane with search results
        await context.dispatch(.pane(.updatePane(files: fileItems)))

        dismiss()
    }
}
