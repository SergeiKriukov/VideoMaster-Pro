//
//  PreviewView.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import SwiftUI
import AVKit

struct PreviewView: View {
    @ObservedObject var viewModel: VideoConverterViewModel
    @State private var selectedFileIndex: Int?
    @State private var isPlaying = false

    var selectedFile: VideoFile? {
        guard let index = selectedFileIndex, index < viewModel.videoFiles.count else { return nil }
        return viewModel.videoFiles[index]
    }

    var body: some View {
        HStack(spacing: 0) {
            // Список файлов слева
            VStack(spacing: 0) {
                Text("Видеофайлы")
                    .font(.headline)
                    .padding()

                Divider()

                if viewModel.videoFiles.isEmpty {
                    VStack {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Нет видеофайлов")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(viewModel.videoFiles.enumerated()), id: \.element.id) { index, file in
                                FilePreviewRow(file: file, isSelected: selectedFileIndex == index)
                                    .onTapGesture {
                                        if selectedFileIndex != index {
                                            isPlaying = false // Stop playback when switching files
                                        }
                                        selectedFileIndex = index
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .frame(width: 300)
            .background(Color.secondary.opacity(0.05))

            Divider()

            // Область предпросмотра справа
            VStack(spacing: 0) {
                if let file = selectedFile {
                    // Видеоплеер
                    VideoPlayerView(url: file.url, isPlaying: $isPlaying)
                        .padding()

                    // Кнопки управления воспроизведением
                    HStack(spacing: 20) {
                        Button(action: {
                            isPlaying.toggle()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: {
                            isPlaying = false
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Информация о файле
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Информация о файле")
                                .font(.title3)
                                .fontWeight(.bold)

                            Group {
                                InfoRow(label: "Имя файла", value: file.fileName)
                                InfoRow(label: "Размер", value: file.formattedFileSize)
                                InfoRow(label: "Длительность", value: file.formattedDuration)

                                if let resolution = file.resolution {
                                    InfoRow(label: "Разрешение", value: "\(Int(resolution.width))×\(Int(resolution.height))")
                                }

                                if let bitrate = file.bitrate {
                                    InfoRow(label: "Битрейт", value: file.formattedBitrate)
                                }

                                InfoRow(label: "Формат", value: file.url.pathExtension.uppercased())
                                InfoRow(label: "Путь", value: file.url.path)
                            }

                            if file.status == .completed, let outputURL = file.outputURL {
                                Divider()

                                Text("Результат конвертации")
                                    .font(.title3)
                                    .fontWeight(.bold)

                                InfoRow(label: "Выходной файл", value: outputURL.lastPathComponent)
                                InfoRow(label: "Папка", value: outputURL.deletingLastPathComponent().path)
                            }

                            if let error = file.errorMessage {
                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ошибка")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)

                                    Text(error)
                                        .foregroundColor(.red)
                                        .font(.callout)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack {
                        Image(systemName: "eye.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Выберите файл для предпросмотра")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

struct FilePreviewRow: View {
    let file: VideoFile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 34)

                if let thumbnail = file.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "video.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .blue : .primary)

                HStack(spacing: 8) {
                    Text(file.formattedDuration)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(file.formattedFileSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(statusColor(for: file.status))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    private func statusColor(for status: ConversionStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
    }
}

struct VideoPlayerView: View {
    let url: URL
    @Binding var isPlaying: Bool
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
                    .frame(height: 300)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(.circular)
                    )
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: isPlaying) { newValue in
            if newValue {
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onChange(of: url) { _ in
            // Recreate player when URL changes
            player?.pause()
            setupPlayer()
        }
    }

    private func setupPlayer() {
        player = AVPlayer(url: url)
    }
}


#Preview {
    let viewModel = VideoConverterViewModel()
    // Add sample data for preview
    return PreviewView(viewModel: viewModel)
}
