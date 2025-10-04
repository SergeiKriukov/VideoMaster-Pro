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

    // MARK: - File Management

    func addFiles(_ urls: [URL]) {
        Task {
            for url in urls {
                guard isVideoFile(url) else { continue }
                
                var videoFile = VideoFile(url: url)
                await loadVideoInfo(for: &videoFile)
                videoFiles.append(videoFile)
            }
        }
    }

    func removeFile(at index: Int) {
        guard index < videoFiles.count else { return }
        videoFiles.remove(at: index)
    }

    func clearAllFiles() {
        videoFiles.removeAll()
    }

    func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mkv", "avi", "webm", "mov", "wmv", "flv", "m4v", "3gp"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }

    private func loadVideoInfo(for videoFile: inout VideoFile) async {
        // Load file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: videoFile.url.path)
            videoFile.fileSize = attributes[.size] as? Int64
        } catch {
            print("Error getting file size: \(error)")
        }

        // Try to get info from AVFoundation first (faster for supported formats)
//        let asset = AVAsset(url: videoFile.url)
//        let asset = AVURLAsset(url: videoFile.url)
//        videoFile.duration = CMTimeGetSeconds(asset.duration)

        do {
            videoFile.duration = try await getVideoDuration(videoFile: videoFile.url)
        } catch {
            print("Error in getVideoDuration: \(error)")
        }
        
//        if let videoTrack = asset.tracks(withMediaType: .video).first {
//            videoFile.resolution = videoTrack.naturalSize
//            videoFile.bitrate = Int(videoTrack.estimatedDataRate)
//
//            // Generate thumbnail
//            let imageGenerator = AVAssetImageGenerator(asset: asset)
//            imageGenerator.appliesPreferredTrackTransform = true
//
//            let time = CMTime(seconds: min(10, CMTimeGetSeconds(asset.duration) / 4), preferredTimescale: 600)
//            do {
//                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
//                videoFile.thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: 200, height: 112))
//            } catch {
//                print("Error generating thumbnail with AVFoundation: \(error)")
//                // Fallback to FFmpeg if needed
//            }
//        }

        @MainActor
        func updateVideoInfo(for asset: AVAsset, videoFile: inout VideoFile) async {
            do {
                // Загружаем видео-треки
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                
                if let videoTrack = videoTracks.first {
                    // Загружаем свойства трека
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)
                    let duration = try await asset.load(.duration)
                    
                    // Обновляем свойства
                    await MainActor.run {
                        videoFile.resolution = naturalSize
                        videoFile.bitrate = Int(estimatedDataRate)
                    }
                    
                    // Генерируем thumbnail
                    let imageGenerator = AVAssetImageGenerator(asset: asset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    
                    let time = CMTime(seconds: min(10, CMTimeGetSeconds(duration) / 4), preferredTimescale: 600)
                    
                    do {
//                        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                        let cgImage = try await imageGenerator.generateCGImage(at: time)
                        await MainActor.run {
                            videoFile.thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: 200, height: 112))
                        }
                    } catch {
                        print("Error generating thumbnail: \(error)")
                    }
                }
            } catch {
                print("Error loading video info: \(error)")
            }
        }
        
        
        
        
        // If AVFoundation failed to get some info, try FFmpeg
        if videoFile.duration == nil || videoFile.resolution == nil {
            let ffmpegInfo = FFmpegService.shared.getVideoInfo(url: videoFile.url)
            if videoFile.duration == nil {
                videoFile.duration = ffmpegInfo.duration
            }
            if videoFile.resolution == nil {
                videoFile.resolution = ffmpegInfo.resolution
            }
            if videoFile.bitrate == nil {
                videoFile.bitrate = ffmpegInfo.bitrate
            }
            videoFile.codec = ffmpegInfo.codec
        }
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
        return outputDir.appendingPathComponent("\(fileName).\(fileExtension)")
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

        semaphore.wait()
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
    
    
    private func getVideoDuration(videoFile: URL) async throws -> Double {
        let asset = AVURLAsset(url: videoFile)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
    
    func generateThumbnailSimple(asset: AVAsset) async -> NSImage? {
        do {
            let duration = try await asset.load(.duration)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
    
            let time = CMTime(seconds: min(10, CMTimeGetSeconds(duration) / 4), preferredTimescale: 600)
            let cgImage = try await imageGenerator.generateCGImage(at: time)
    
            return NSImage(cgImage: cgImage, size: NSSize(width: 200, height: 112))
        } catch {
            print("Error: \(error)")
            return nil
        }
    }

    
}




extension AVAssetImageGenerator {
    func generateCGImage(at time: CMTime) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            self.generateCGImageAsynchronously(for: time) {
                image,
                actualTime,
                error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "AVFoundationError",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to generate image"]
                        )
                    )
                }
            }
        }
    }
}

