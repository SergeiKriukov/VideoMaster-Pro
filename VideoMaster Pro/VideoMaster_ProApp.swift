//
//  VideoMaster_ProApp.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import SwiftUI
import AppKit

@main
struct VideoMaster_ProApp: App {
    @State private var showFFmpegAlert = false
    @State private var logsAutoRefresh = true

    var body: some Scene {
        WindowGroup("VideoMaster Pro", content: {
            MainView()
                .alert("FFmpeg не найден", isPresented: $showFFmpegAlert) {
                    Button("Установить") { openTerminalWithBrewInstall() }
                    Button("Позже", role: .cancel) {}
                } message: {
                    Text("Для работы приложения требуется FFmpeg. Установите его через Homebrew командой:\n\nbrew install ffmpeg")
                }
                .onAppear { checkFFmpegInstallation() }
        })
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Логи") {
                Button("Открыть папку с логами") {
                    let url = VideoConverterViewModel.shared.getLogFileURLForMenu().deletingLastPathComponent()
                    NSWorkspace.shared.open(url)
                }

                Button("Обновить логи") {
                    // no-op: команда для UI; основное чтение делается в LogsView, здесь просто удобный триггер
                    // Можно в будущем повесить notification
                }

                Toggle("Автообновление логов", isOn: $logsAutoRefresh)

                Divider()

                Button("Скопировать последние 200 строк") {
                    let text = VideoConverterViewModel.shared.getRecentLogsForMenu(lines: 200)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
        }
    }

    private func checkFFmpegInstallation() {
        if !FFmpegService.shared.checkFFmpegInstallation() {
            showFFmpegAlert = true
        }
    }

    private func openTerminalWithBrewInstall() {
        let script = """
        tell application "Terminal"
            do script "brew install ffmpeg"
            activate
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
    }
}
