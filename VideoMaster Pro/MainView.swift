//
//  ContentView.swift
//  VideoMaster Pro
//
//  Created by Сергей Крюков, Александр Анишин, Евгений Турчанинов on 22.09.2025.
//  Email: info@lawlabs.ru
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
        let lock = NSLock()
        var urls: [URL] = []
        var completedCount = 0

        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                lock.lock()
                if let urlData = urlData as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    urls.append(url)
                }
                completedCount += 1

                // When all providers are processed, add files
                if completedCount == providers.count && !urls.isEmpty {
                    DispatchQueue.main.async {
                        self.viewModel.addFiles(urls)
                    }
                }
                lock.unlock()
            }
        }

        return true
    }
}

#Preview {
    MainView()
}
