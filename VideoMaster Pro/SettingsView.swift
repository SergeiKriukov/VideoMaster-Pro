//
//  SettingsView.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import SwiftUI

struct SettingsView: View {
    @State private var isShowingOutputFolderPicker = false
    
    @StateObject private var viewModel = VideoConverterViewModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Заголовок
                Text("Расширенные настройки")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                // Видео настройки
                VideoSettingsSection()

                Divider()

                // Аудио настройки
                AudioSettingsSection()

                Divider()

                // Выходные настройки
                OutputSettingsSection(isShowingFolderPicker: $isShowingOutputFolderPicker)

                Divider()

                // Пресеты
                PresetsSection()

                Divider()

                // Системные настройки
                SystemSettingsSection()
            }
            .padding()
        }
        .fileImporter(
            isPresented: $isShowingOutputFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.conversionSettings.outputDirectory = urls
            case .failure(let error):
                print("Error selecting output folder: \(error)")
            }
        }
    }
}

private struct VideoSettingsSection: View {
    @StateObject private var viewModel = VideoConverterViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎬 Видео")
                .font(.headline)

            VStack(spacing: 12) {
                // Кодек видео
                SettingRow(label: "Кодек") {
                    Picker("", selection: $viewModel.conversionSettings.videoCodec) {
                        ForEach(VideoCodec.allCases, id: \.self) { codec in
                            Text(codec.rawValue).tag(codec)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }

                // Качество
                if viewModel.conversionSettings.videoCodec != .copy {
                    SettingRow(label: "Качество (CRF)") {
                        VStack(alignment: .leading, spacing: 4) {
                            Slider(value: $viewModel.conversionSettings.videoQuality, in: 0...51, step: 1)
                                .frame(width: 300)

                            HStack {
                                Text("0 (лучшее)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(viewModel.conversionSettings.videoQuality))")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("51 (худшее)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Text("CRF (Constant Rate Factor) - чем меньше значение, тем лучше качество и больше размер файла")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 120)
                }

                // Разрешение
                SettingRow(label: "Разрешение") {
                    Picker("", selection: $viewModel.conversionSettings.resolution) {
                        Text("Оригинал").tag("Оригинал")
                        Text("4K (3840x2160)").tag("3840x2160")
                        Text("Full HD (1920x1080)").tag("1920x1080")
                        Text("HD (1280x720)").tag("1280x720")
                        Text("SD (854x480)").tag("854x480")
                        Text("Кастомное").tag("Кастомное")
                    }
                    .frame(width: 200)
                }

                // Кастомное разрешение
                if viewModel.conversionSettings.resolution == "Кастомное" {
                    HStack(spacing: 12) {
                        Spacer()
                            .frame(width: 120)

                        HStack(spacing: 8) {
                            TextField("Ширина", value: $viewModel.conversionSettings.customWidth, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)

                            Text("×")

                            TextField("Высота", value: $viewModel.conversionSettings.customHeight, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)

                            Text("px")
                        }
                    }
                }

                // Соотношение сторон
                SettingRow(label: "Соотношение") {
                    Picker("", selection: $viewModel.conversionSettings.aspectRatio) {
                        Text("Авто").tag("Авто")
                        Text("16:9").tag("16:9")
                        Text("4:3").tag("4:3")
                        Text("1:1").tag("1:1")
                        Text("21:9").tag("21:9")
                    }
                    .frame(width: 150)
                }
            }
        }
    }
}

struct AudioSettingsSection: View {
    @StateObject private var viewModel = VideoConverterViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🔊 Аудио")
                .font(.headline)

            VStack(spacing: 12) {
                // Кодек аудио
                SettingRow(label: "Кодек") {
                    Picker("", selection: $viewModel.conversionSettings.audioCodec) {
                        ForEach(AudioCodec.allCases, id: \.self) { codec in
                            Text(codec.rawValue).tag(codec)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }

                // Битрейт аудио
                if viewModel.conversionSettings.audioCodec != .copy {
                    SettingRow(label: "Битрейт") {
                        VStack(alignment: .leading, spacing: 4) {
                            Slider(value: Binding(
                                get: { Double(viewModel.conversionSettings.audioBitrate) },
                                set: { viewModel.conversionSettings.audioBitrate = Int($0) }
                            ), in: 64...320, step: 32)
                            .frame(width: 300)

                            HStack {
                                Text("64 kb/s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(viewModel.conversionSettings.audioBitrate) kb/s")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("320 kb/s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Нормализация
                SettingRow(label: "Нормализация") {
                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                    Text("Автоматическая нормализация громкости")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Каналы
                SettingRow(label: "Каналы") {
                    Picker("", selection: .constant("Стерео")) {
                        Text("Моно").tag("Моно")
                        Text("Стерео").tag("Стерео")
                        Text("5.1").tag("5.1")
                        Text("7.1").tag("7.1")
                    }
                    .frame(width: 150)
                    .disabled(true) // Пока не реализовано
                }
            }
        }
    }
}

struct OutputSettingsSection: View {
    @Binding var isShowingFolderPicker: Bool
    
    @StateObject private var viewModel = VideoConverterViewModel.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📁 Выход")
                .font(.headline)

            VStack(spacing: 12) {
                // Формат файла
                SettingRow(label: "Формат") {
                    Picker("", selection: $viewModel.conversionSettings.outputFormat) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }

                // Папка назначения
                SettingRow(label: "Папка") {
                    HStack {
                        Text(viewModel.conversionSettings.outputDirectory?.path ?? "Та же папка")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 250, alignment: .leading)

                        Button(action: { isShowingFolderPicker = true }) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.bordered)

                        if viewModel.conversionSettings.outputDirectory != nil {
                            Button(action: { viewModel.conversionSettings.outputDirectory = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Шаблон имени файла
                SettingRow(label: "Имя файла") {
                    TextField("", text: $viewModel.conversionSettings.fileNameTemplate)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Доступные переменные:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("{original} - оригинальное имя, {quality} - качество видео")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 120)
            }
        }
    }
}

struct PresetsSection: View {
    @StateObject private var viewModel = VideoConverterViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("💾 Пресеты")
                    .font(.headline)

                Spacer()

                Button(action: { /* Create new preset */ }) {
                    Label("Создать", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button(action: { /* Save current settings */ }) {
                    Label("Сохранить", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }

            VStack(spacing: 8) {
                PresetRow(name: "Web (720p)", description: "Для веба, MP4, H.264, 720p")
                PresetRow(name: "HD Качество", description: "Full HD, высокое качество, MP4")
                PresetRow(name: "Компактный", description: "Маленький размер, MP4, H.265")
                PresetRow(name: "Аудио только", description: "Извлечение аудио, MP3")
            }
        }
    }
}

struct PresetRow: View {
    let name: String
    let description: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { /* Load preset */ }) {
                Text("Загрузить")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SystemSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("⚙️ Система")
                .font(.headline)

            VStack(spacing: 12) {
                SettingRow(label: "Максимум задач") {
                    Picker("", selection: .constant(2)) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                    }
                    .frame(width: 80)
                    .disabled(true) // Пока не реализовано
                }

                SettingRow(label: "Удалять оригиналы") {
                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                    Text("После успешной конвертации")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                SettingRow(label: "Уведомления") {
                    Toggle("", isOn: .constant(true))
                        .labelsHidden()
                    Text("Показывать уведомления о завершении")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct SettingRow<Content: View>: View {
    let label: String
    let content: Content
    
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .frame(width: 120, alignment: .leading)
                .font(.callout)
                .foregroundColor(.secondary)
            
            content
        }
    }
}

#Preview {
    SettingsView()
}
