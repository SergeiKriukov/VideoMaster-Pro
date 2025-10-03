//
//  FFmpegService.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import Foundation
import Combine

class FFmpegService {
    static let shared = FFmpegService()

    private let logger = Logger()

    private init() {}

    func checkFFmpegInstallation() -> Bool {
        logger.log("Проверка установки FFmpeg", level: .info)

        let possiblePaths = ["/usr/local/bin/ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/bin/ffmpeg"]

        for path in possiblePaths {
            logger.log("Проверка пути: \(path)", level: .debug)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["-version"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    logger.log("FFmpeg найден по пути: \(path)", level: .info)
                    return true
                } else {
                    logger.log("FFmpeg по пути \(path) вернул код выхода: \(process.terminationStatus)", level: .warning)
                }
            } catch {
                logger.log("Ошибка при проверке FFmpeg по пути \(path): \(error.localizedDescription)", level: .warning)
            }
        }

        logger.log("FFmpeg не найден ни по одному из стандартных путей", level: .error)
        return false
    }

    func getFFmpegPath() -> String? {
        // First try to use 'which' command to find ffmpeg
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    logger.log("FFmpeg найден через 'which': \(output)", level: .info)
                    return output
                }
            }
        } catch {
            logger.log("Ошибка выполнения 'which ffmpeg': \(error.localizedDescription)", level: .warning)
        }

        // Check common locations
        let possiblePaths = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
            "/usr/bin/ffmpeg",
            "/opt/local/bin/ffmpeg", // MacPorts
            "/sw/bin/ffmpeg" // Fink
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                logger.log("FFmpeg найден по пути: \(path)", level: .info)
                return path
            }
        }

        logger.log("FFmpeg не найден ни по одному из стандартных путей", level: .error)
        return nil
    }

    func convertVideo(
        inputURL: URL,
        outputURL: URL,
        settings: ConversionSettings,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Bool, String?) -> Void
    ) {
        logger.log("Начинаем конвертацию видео", level: .info)
        logger.log("Входной файл: \(inputURL.path)", level: .info)
        logger.log("Выходной файл: \(outputURL.path)", level: .info)

        guard let ffmpegPath = getFFmpegPath() else {
            let errorMsg = "FFmpeg не найден. Установите FFmpeg через Homebrew: brew install ffmpeg"
            logger.log(errorMsg, level: .error)
            completion(false, errorMsg)
            return
        }

        logger.log("Используем FFmpeg: \(ffmpegPath)", level: .info)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)

        // Build FFmpeg arguments
        var arguments = ["-i", inputURL.path]

        // Video settings
        if settings.videoCodec != .copy {
            arguments.append("-c:v")
            arguments.append(settings.videoCodec.ffmpegCodec)

            if settings.videoCodec == .h264 || settings.videoCodec == .h265 {
                arguments.append("-crf")
                arguments.append("\(Int(settings.videoQuality))")
                logger.log("Видео кодек: \(settings.videoCodec.rawValue), качество: \(Int(settings.videoQuality))", level: .info)
            } else {
                logger.log("Видео кодек: \(settings.videoCodec.rawValue)", level: .info)
            }
        } else {
            arguments.append("-c:v")
            arguments.append("copy")
            logger.log("Видео: копирование без перекодирования", level: .info)
        }

        // Audio settings
        if settings.audioCodec != .copy {
            arguments.append("-c:a")
            arguments.append(settings.audioCodec.ffmpegCodec)

            if settings.audioCodec == .aac || settings.audioCodec == .mp3 {
                arguments.append("-b:a")
                arguments.append("\(settings.audioBitrate)k")
                logger.log("Аудио кодек: \(settings.audioCodec.rawValue), битрейт: \(settings.audioBitrate)k", level: .info)
            } else {
                logger.log("Аудио кодек: \(settings.audioCodec.rawValue)", level: .info)
            }
        } else {
            arguments.append("-c:a")
            arguments.append("copy")
            logger.log("Аудио: копирование без перекодирования", level: .info)
        }

        // Output format
        arguments.append("-f")
        arguments.append(settings.outputFormat.rawValue.lowercased())

        // Output file
        arguments.append(outputURL.path)

        process.arguments = arguments

        logger.log("FFmpeg команда: \(arguments.joined(separator: " "))", level: .debug)

        // Set up pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Progress monitoring
        var progressObserver: NSObjectProtocol?

        if let progressFileURL = createProgressFile() {
            // FFmpeg progress monitoring setup
            let progressPath = progressFileURL.path
            process.arguments?.insert(contentsOf: ["-progress", progressPath], at: 0)

            progressObserver = monitorProgressFile(progressFileURL, handler: progressHandler)
        }

        // Run process
        do {
            logger.log("Запускаем FFmpeg процесс", level: .info)
            try process.run()

            // Monitor progress in background
            DispatchQueue.global(qos: .background).async {
                self.logger.log("Ожидаем завершения FFmpeg процесса", level: .debug)
                process.waitUntilExit()

                // Clean up progress observer
                if let observer = progressObserver {
                    NotificationCenter.default.removeObserver(observer)
                }

                let success = process.terminationStatus == 0
                var errorMessage: String?

                if !success {
                    // Read error output
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if let errorString = String(data: errorData, encoding: .utf8) {
                        errorMessage = errorString
                        self.logger.log("FFmpeg вернул ошибку (код \(process.terminationStatus)):", level: .error)
                        self.logger.log("Подробности ошибки:\n\(errorString)", level: .error)
                    } else {
                        errorMessage = "FFmpeg завершился с кодом ошибки \(process.terminationStatus), но не предоставил детали"
                        self.logger.log(errorMessage!, level: .error)
                    }
                } else {
                    self.logger.log("FFmpeg успешно завершил конвертацию", level: .info)
                }

                DispatchQueue.main.async {
                    completion(success, errorMessage)
                }
            }
        } catch {
            let errorMsg = "Ошибка запуска FFmpeg: \(error.localizedDescription)"
            logger.log(errorMsg, level: .error)
            completion(false, errorMsg)
        }
    }

    private func createProgressFile() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let progressFileName = "ffmpeg_progress_\(UUID().uuidString).txt"
        return tempDir.appendingPathComponent(progressFileName)
    }

    private func monitorProgressFile(_ fileURL: URL, handler: @escaping (Double) -> Void) -> NSObjectProtocol? {
        return Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)

                var duration: Double = 0
                var currentTime: Double = 0

                for line in lines {
                    let components = line.components(separatedBy: "=")
                    if components.count == 2 {
                        let key = components[0].trimmingCharacters(in: .whitespaces)
                        let value = components[1].trimmingCharacters(in: .whitespaces)

                        if key == "duration" {
                            duration = self.timeStringToSeconds(value)
                        } else if key == "out_time" {
                            currentTime = self.timeStringToSeconds(value)
                        }
                    }
                }

                if duration > 0 {
                    let progress = min(currentTime / duration, 1.0)
                    handler(progress)
                }

            } catch {
                // File might not exist yet or be empty
            }
        }
    }

    private func timeStringToSeconds(_ timeString: String) -> Double {
        let components = timeString.components(separatedBy: ":")
        guard components.count >= 3 else { return 0 }

        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0

        return hours * 3600 + minutes * 60 + seconds
    }

    func getVideoInfo(url: URL) -> (duration: Double?, resolution: CGSize?, bitrate: Int?, codec: String?) {
        guard let ffmpegPath = getFFmpegPath() else { return (nil, nil, nil, nil) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = ["-i", url.path]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            // Parse FFmpeg output for video information
            var duration: Double?
            var resolution: CGSize?
            var bitrate: Int?
            var codec: String?

            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                // Duration
                if line.contains("Duration:"), let range = line.range(of: "Duration: ([0-9:.]+)", options: .regularExpression) {
                    let timeString = String(line[range])
                    duration = timeStringToSeconds(timeString.replacingOccurrences(of: "Duration: ", with: ""))
                }

                // Video stream info
                if line.contains("Video:"), let streamRange = line.range(of: "Video: ([^,]+)", options: .regularExpression) {
                    codec = String(line[streamRange]).replacingOccurrences(of: "Video: ", with: "")
                }

                // Resolution
                if line.contains(", ") && line.contains("x"), let resRange = line.range(of: "([0-9]+x[0-9]+)", options: .regularExpression) {
                    let resString = String(line[resRange])
                    let components = resString.components(separatedBy: "x")
                    if components.count == 2,
                       let width = Double(components[0]),
                       let height = Double(components[1]) {
                        resolution = CGSize(width: width, height: height)
                    }
                }

                // Bitrate
                if line.contains("bitrate:"), let bitrateRange = line.range(of: "bitrate: ([0-9]+)", options: .regularExpression) {
                    bitrate = Int(String(line[bitrateRange]).replacingOccurrences(of: "bitrate: ", with: ""))
                }
            }

            process.waitUntilExit()
            return (duration, resolution, bitrate, codec)

        } catch {
            print("Error getting video info: \(error)")
            return (nil, nil, nil, nil)
        }
    }
}
