//
//  VideoMaster_ProApp.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import SwiftUI

@main
struct VideoMaster_ProApp: App {
    @State private var showFFmpegAlert = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert("FFmpeg не найден", isPresented: $showFFmpegAlert) {
                    Button("Установить") {
                        openTerminalWithBrewInstall()
                    }
                    Button("Позже", role: .cancel) {}
                } message: {
                    Text("Для работы приложения требуется FFmpeg. Установите его через Homebrew командой:\n\nbrew install ffmpeg")
                }
                .onAppear {
                    checkFFmpegInstallation()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
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
