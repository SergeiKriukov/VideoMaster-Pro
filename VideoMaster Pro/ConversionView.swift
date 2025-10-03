//
//  ConversionView.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ConversionView: View {
    @ObservedObject var viewModel: VideoConverterViewModel
    @State private var isShowingFilePicker = false
    @State private var isShowingFolderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок и кнопки
            HStack {
                Text("Конвертация видео")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { isShowingFilePicker = true }) {
                    Label("Добавить файлы", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button(action: { isShowingFolderPicker = true }) {
                    Label("Выбрать папку", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                if !viewModel.videoFiles.isEmpty {
                    Button(action: { viewModel.clearAllFiles() }) {
                        Label("Очистить", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding()

            Divider()

            // Область перетаскивания файлов
            if viewModel.videoFiles.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundColor(.secondary.opacity(0.3))
                        .frame(height: 200)

                    VStack(spacing: 16) {
                        Image(systemName: "video.fill.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Перетащите видеофайлы сюда")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("или используйте кнопки выше")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .padding()
            } else {
                // Список файлов
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.videoFiles.enumerated()), id: \.element.id) { index, file in
                            VideoFileRow(file: file, index: index, viewModel: viewModel)
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Настройки конвертации
            ConversionSettingsView(viewModel: viewModel)
                .padding()

            // Панель управления
            HStack {
                if viewModel.isConverting {
                    ProgressView(value: viewModel.totalProgress) {
                        Text("Конвертация: \(viewModel.currentFileIndex + 1) из \(viewModel.videoFiles.count)")
                    }
                    .progressViewStyle(.linear)

                    Button(action: { viewModel.cancelConversion() }) {
                        Label("Отмена", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                } else {
                    Button(action: { viewModel.startConversion() }) {
                        Label("Начать конвертацию", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.videoFiles.isEmpty)
                }

                Spacer()

                Text("\(viewModel.videoFiles.count) файлов")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.addFiles(urls)
            case .failure(let error):
                print("Error selecting files: \(error)")
            }
        }
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let urls):
                // Load all video files from folder
                loadVideoFilesFromFolder(urls)
            case .failure(let error):
                print("Error selecting folder: \(error)")
            }
        }
    }

    private func loadVideoFilesFromFolder(_ folderURL: URL) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: nil) else { return }

        var videoURLs: [URL] = []

        for case let url as URL in enumerator {
            if viewModel.isVideoFile(url) {
                videoURLs.append(url)
            }
        }

        viewModel.addFiles(videoURLs)
    }
}

struct VideoFileRow: View {
    let file: VideoFile
    let index: Int
    @ObservedObject var viewModel: VideoConverterViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 45)

                if let thumbnail = file.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "video.fill")
                        .foregroundColor(.secondary)
                }
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 16) {
                    Text(file.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(file.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let resolution = file.resolution {
                        Text("\(Int(resolution.width))×\(Int(resolution.height))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Status and progress
            VStack(alignment: .trailing, spacing: 4) {
                Text(file.status.rawValue)
                    .font(.caption)
                    .foregroundColor(statusColor(for: file.status))

                if file.status == .processing {
                    ProgressView(value: file.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                } else if file.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if file.status == .failed {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }

            // Remove button
            Button(action: { viewModel.removeFile(at: index) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusColor(for status: ConversionStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

struct ConversionSettingsView: View {
    @ObservedObject var viewModel: VideoConverterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Настройки конвертации")
                .font(.headline)

            HStack(spacing: 20) {
                // Формат вывода
                VStack(alignment: .leading) {
                    Text("Формат")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.conversionSettings.outputFormat) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                // Кодек видео
                VStack(alignment: .leading) {
                    Text("Видео кодек")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.conversionSettings.videoCodec) {
                        ForEach(VideoCodec.allCases, id: \.self) { codec in
                            Text(codec.rawValue).tag(codec)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                // Качество видео
                VStack(alignment: .leading) {
                    Text("Качество (CRF)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: $viewModel.conversionSettings.videoQuality, in: 0...51, step: 1)
                        .frame(width: 120)

                    Text("\(Int(viewModel.conversionSettings.videoQuality))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Кодек аудио
                VStack(alignment: .leading) {
                    Text("Аудио кодек")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.conversionSettings.audioCodec) {
                        ForEach(AudioCodec.allCases, id: \.self) { codec in
                            Text(codec.rawValue).tag(codec)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                // Битрейт аудио
                VStack(alignment: .leading) {
                    Text("Аудио битрейт")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Slider(value: Binding(
                            get: { Double(viewModel.conversionSettings.audioBitrate) },
                            set: { viewModel.conversionSettings.audioBitrate = Int($0) }
                        ), in: 64...320, step: 32)
                        .frame(width: 100)

                        Text("\(viewModel.conversionSettings.audioBitrate)k")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .leading)
                    }
                }
            }
        }
    }
}

#Preview {
    ConversionView(viewModel: VideoConverterViewModel())
}
