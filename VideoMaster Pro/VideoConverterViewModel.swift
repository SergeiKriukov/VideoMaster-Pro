//
//  VideoConverterViewModel.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import SwiftUI
import AVFoundation
import Combine

final class VideoConverterViewModel: ObservableObject {
    @Published var videoFiles: [VideoFile] = []
    @Published var conversionSettings = ConversionSettings()
    @Published var isConverting = false
    @Published var currentFileIndex = 0
    @Published var totalProgress: Double = 0.0
    @Published var lastErrorMessage: String?
    @Published var showErrorAlert = false

    static let shared = VideoConverterViewModel()
    
    private init() {}
    
    private var cancellables = Set<AnyCancellable>()
    private var conversionQueue = DispatchQueue(label: "com.videomaster.conversion", qos: .userInitiated)
    private let logger = Logger.shared

    // MARK: - Logs helpers for menu commands
    func getLogFileURLForMenu() -> URL { logger.getLogFileURL() }
    func getRecentLogsForMenu(lines: Int = 50) -> String { logger.getRecentLogs(lines: lines) }

    // MARK: - File Management

    func addFiles(_ urls: [URL]) {
        Task {
            for url in urls {
                guard isVideoFile(url) else { continue }

                let videoFile = await loadVideoInfo(for: url)

                // Update UI on main thread
                await MainActor.run {
                    videoFiles.append(videoFile)
                }
            }
        }
    }

    @MainActor
    func removeFile(at index: Int) {
        guard index < videoFiles.count else { return }
        videoFiles.remove(at: index)
    }

    @MainActor
    func clearAllFiles() {
        videoFiles.removeAll()
    }

    func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mkv", "avi", "webm", "mov", "wmv", "flv", "m4v", "3gp"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }

    private func loadVideoInfo(for url: URL) async -> VideoFile {
        var videoFile = VideoFile(url: url)

        // Load file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            videoFile.fileSize = attributes[.size] as? Int64

            // Check if file is too small (less than 1KB) - might be corrupted
            if let size = videoFile.fileSize, size < 1024 {
                logger.log("Файл слишком маленький (\(size) байт), возможно поврежден: \(url.lastPathComponent)", level: .warning)
                return videoFile
            }
        } catch {
            logger.log("Ошибка получения размера файла: \(error.localizedDescription)", level: .error)
        }

        // Try to get video info and generate thumbnail using AVFoundation
        var avFoundationFailed = false
        do {
            let asset = AVURLAsset(url: url)

            // Get duration if not already loaded
            if videoFile.duration == nil {
                let duration = try await asset.load(.duration)
                videoFile.duration = CMTimeGetSeconds(duration)
            }

            // Load video tracks
            let videoTracks = try await asset.loadTracks(withMediaType: .video)

            if let videoTrack = videoTracks.first {
                // Load video properties
                let naturalSize = try await videoTrack.load(.naturalSize)
                let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)

                print("DEBUG: AVFoundation naturalSize = \(naturalSize), estimatedDataRate = \(estimatedDataRate)")
                videoFile.resolution = naturalSize
                videoFile.bitrate = Int(estimatedDataRate)

                // Generate thumbnail
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true

                // Calculate thumbnail size maintaining aspect ratio
                let maxThumbnailSize: CGFloat = 200
                let aspectRatio = naturalSize.width / naturalSize.height

                var thumbnailSize: CGSize
                if aspectRatio > 1 {
                    // Landscape/horizontal video
                    thumbnailSize = CGSize(width: maxThumbnailSize, height: maxThumbnailSize / aspectRatio)
                } else {
                    // Portrait/vertical video or square
                    thumbnailSize = CGSize(width: maxThumbnailSize * aspectRatio, height: maxThumbnailSize)
                }

                // Ensure minimum size
                thumbnailSize.width = max(thumbnailSize.width, 80)
                thumbnailSize.height = max(thumbnailSize.height, 45)

                imageGenerator.maximumSize = thumbnailSize

                let duration = try await asset.load(.duration)
                let time = CMTime(seconds: min(10, CMTimeGetSeconds(duration) / 4), preferredTimescale: 600)

                do {
                    // Use synchronous method for better compatibility
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                    videoFile.thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: thumbnailSize.width, height: thumbnailSize.height))
                } catch {
                    logger.log("Ошибка генерации миниатюры с AVFoundation: \(error.localizedDescription)", level: .warning)
                }
            }
        } catch {
            avFoundationFailed = true
            let errorMessage = error.localizedDescription
            if errorMessage.contains("media format is not supported") ||
               errorMessage.contains("Cannot Open") {
                logger.log("AVFoundation не поддерживает формат файла, используем FFmpeg: \(url.lastPathComponent)", level: .info)
            } else {
                logger.log("Ошибка загрузки информации о видео с AVFoundation: \(errorMessage)", level: .warning)
            }
        }
        // Always try to get additional info from FFmpeg (especially for unsupported formats)
        // But only if we haven't already determined the file might be corrupted
        if videoFile.fileSize == nil || (videoFile.fileSize ?? 0) >= 1024 {
            let ffmpegInfo = FFmpegService.shared.getVideoInfo(url: videoFile.url)
            if videoFile.duration == nil && ffmpegInfo.duration != nil {
                videoFile.duration = ffmpegInfo.duration
            }
            if videoFile.resolution == nil && ffmpegInfo.resolution != nil {
                videoFile.resolution = ffmpegInfo.resolution
            }
            if videoFile.bitrate == nil && ffmpegInfo.bitrate != nil {
                videoFile.bitrate = ffmpegInfo.bitrate
            }
            if videoFile.codec == nil && ffmpegInfo.codec != nil {
                videoFile.codec = ffmpegInfo.codec
            }
        }

        return videoFile
    }

    // MARK: - Conversion

    func startConversion() {
        guard !videoFiles.isEmpty else { return }

        isConverting = true
        currentFileIndex = 0
        totalProgress = 0.0

        conversionQueue.async { [weak self] in
            self?.convertFiles()
        }
    }

    func cancelConversion() {
        isConverting = false
        // Cancel current FFmpeg process
    }

    private func convertFiles() {
        for (index, _) in videoFiles.enumerated() {
            guard isConverting else { break }

            DispatchQueue.main.async { [weak self] in
                self?.currentFileIndex = index
            }

            convertFile(at: index)

            DispatchQueue.main.async { [weak self] in
                self?.totalProgress = Double(index + 1) / Double(self?.videoFiles.count ?? 1)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.isConverting = false
        }
    }

    private func convertFile(at index: Int) {
        guard index < videoFiles.count else { return }

        var file = videoFiles[index]
        file.status = .processing

        DispatchQueue.main.async { [weak self] in
            self?.videoFiles[index] = file
        }

        let outputURL = generateOutputURL(for: file)

        logger.log("Выходной файл: \(outputURL.path)", level: .info)

        let success = runFFmpeg(inputURL: file.url, outputURL: outputURL, settings: conversionSettings) { progress in
            DispatchQueue.main.async { [weak self] in
                if var updatedFile = self?.videoFiles[index] {
                    updatedFile.progress = progress
                    self?.videoFiles[index] = updatedFile
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            if var updatedFile = self?.videoFiles[index] {
                if success {
                    updatedFile.status = .completed
                    updatedFile.outputURL = outputURL
                } else {
                    updatedFile.status = .failed
                    updatedFile.errorMessage = "Ошибка конвертации"
                }
                updatedFile.progress = 1.0
                self?.videoFiles[index] = updatedFile
            }
        }
    }

    private func generateOutputURL(for file: VideoFile) -> URL {
        let outputDir = conversionSettings.outputDirectory ?? file.url.deletingLastPathComponent()

        var fileName = conversionSettings.fileNameTemplate
        fileName = fileName.replacingOccurrences(of: "{original}", with: file.fileNameWithoutExtension)
        fileName = fileName.replacingOccurrences(of: "{quality}", with: "\(Int(conversionSettings.videoQuality))")

        let fileExtension = conversionSettings.outputFormat.fileExtension
        var outputURL = outputDir.appendingPathComponent("\(fileName).\(fileExtension)")

        // If file already exists, add a suffix
        var counter = 1
        let originalFileName = fileName
        while FileManager.default.fileExists(atPath: outputURL.path) {
            fileName = "\(originalFileName)_\(counter)"
            outputURL = outputDir.appendingPathComponent("\(fileName).\(fileExtension)")
            counter += 1
        }

        return outputURL
    }

    private func runFFmpeg(inputURL: URL, outputURL: URL, settings: ConversionSettings, progressHandler: @escaping (Double) -> Void) -> Bool {
        logger.log("Начинаем конвертацию файла: \(inputURL.lastPathComponent)", level: .info)

        var conversionSuccess = false
//        var errorMessage: String?

        let semaphore = DispatchSemaphore(value: 0)

        FFmpegService.shared.convertVideo(
            inputURL: inputURL,
            outputURL: outputURL,
            settings: settings,
            progressHandler: progressHandler
        ) { success, error in
            conversionSuccess = success
//            errorMessage = error

            if success {
                self.logger.log("Конвертация файла \(inputURL.lastPathComponent) завершена успешно", level: .info)
            } else {
                self.logger.log("Ошибка конвертации файла \(inputURL.lastPathComponent): \(error ?? "неизвестная ошибка")", level: .error)

                // Show error to user
                DispatchQueue.main.async {
                    self.lastErrorMessage = error ?? "Неизвестная ошибка конвертации"
                    self.showErrorAlert = true
                }
            }

            semaphore.signal()
        }

        // Wait for completion with timeout (30 minutes max for video conversion)
        let timeoutResult = semaphore.wait(timeout: .now() + 1800)

        if timeoutResult == .timedOut {
            logger.log("Таймаут конвертации файла \(inputURL.lastPathComponent) (30 минут)", level: .error)
            DispatchQueue.main.async {
                self.lastErrorMessage = "Превышено время ожидания конвертации (30 минут)"
                self.showErrorAlert = true
            }
            return false
        }

        return conversionSuccess
    }

    // MARK: - Logging

    func getRecentLogs() -> String {
        logger.getRecentLogs()
    }

    func getLogFileURL() -> URL {
        logger.getLogFileURL()
    }

    func clearError() {
        lastErrorMessage = nil
        showErrorAlert = false
    }

}

