//
//  LogsView.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import SwiftUI

struct LogsView: View {
    @ObservedObject var viewModel: VideoConverterViewModel
    @State private var logsText: String = ""
    @State private var autoRefresh = true
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок и кнопки
            HStack {
                Text("Логи приложения")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Toggle("Автообновление", isOn: $autoRefresh)
                    .toggleStyle(.switch)

                Button(action: refreshLogs) {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button(action: openLogFile) {
                    Label("Открыть файл", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button(action: clearLogs) {
                    Label("Очистить", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding()

            Divider()

            // Область с логами
            ScrollView {
                Text(logsText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.black.opacity(0.05))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            refreshLogs()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: autoRefresh) { newValue in
            if newValue {
                startAutoRefresh()
            } else {
                stopAutoRefresh()
            }
        }
    }

    private func refreshLogs() {
        logsText = viewModel.getRecentLogs()
    }

    private func openLogFile() {
        let logURL = viewModel.getLogFileURL()
        NSWorkspace.shared.open(logURL.deletingLastPathComponent())
    }

    private func clearLogs() {
        // Note: Logger doesn't have a clear method, so we'll just refresh
        refreshLogs()
    }

    private func startAutoRefresh() {
        guard autoRefresh else { return }

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            refreshLogs()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

#Preview {
    LogsView(viewModel: VideoConverterViewModel())
}
