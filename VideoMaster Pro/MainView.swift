//
//  ContentView.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @State private var selectedTab = 0
    @StateObject private var viewModel = VideoConverterViewModel.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            // Вкладка Конвертация
            ConversionView()
                .tabItem {
                    Label("Конвертация", systemImage: "video.fill")
                }
                .tag(0)

            // Вкладка Предпросмотр
            PreviewView()
                .tabItem {
                    Label("Предпросмотр", systemImage: "eye.fill")
                }
                .tag(1)

            // Вкладка Настройки
            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
                .tag(2)

            // Вкладка Логи
            LogsView()
                .tabItem {
                    Label("Логи", systemImage: "doc.text")
                }
                .tag(3)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers: providers)
        }
        .alert("Ошибка конвертации", isPresented: $viewModel.showErrorAlert) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.lastErrorMessage ?? "Неизвестная ошибка")
        }
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                if let urlData = urlData as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.viewModel.addFiles([url])
                    }
                }
            }
        }
        return true
    }
}

#Preview {
    MainView()
}
