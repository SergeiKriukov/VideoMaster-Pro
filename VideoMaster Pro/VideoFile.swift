//
//  VideoFile.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import AVFoundation
import SwiftUI

enum ConversionStatus: String {
    case pending = "Ожидает"
    case processing = "Конвертируется"
    case completed = "Готово"
    case failed = "Ошибка"
    case cancelled = "Отменено"
}

enum VideoCodec: String, CaseIterable {
    case h264 = "H.264"
    case h265 = "H.265"
    case av1 = "AV1"
    case vp9 = "VP9"
    case copy = "Копировать"

    var ffmpegCodec: String {
        switch self {
        case .h264: return "libx264"
        case .h265: return "libx265"
        case .av1: return "libaom-av1"
        case .vp9: return "libvpx-vp9"
        case .copy: return "copy"
        }
    }
}

enum AudioCodec: String, CaseIterable {
    case aac = "AAC"
    case mp3 = "MP3"
    case opus = "Opus"
    case copy = "Копировать"

    var ffmpegCodec: String {
        switch self {
        case .aac: return "aac"
        case .mp3: return "libmp3lame"
        case .opus: return "libopus"
        case .copy: return "copy"
        }
    }
}

enum OutputFormat: String, CaseIterable {
    case mp4 = "MP4"
    case mkv = "MKV"
    case avi = "AVI"
    case webm = "WebM"

    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mkv: return "mkv"
        case .avi: return "avi"
        case .webm: return "webm"
        }
    }

    var ffmpegFormat: String {
        switch self {
        case .mp4: return "mp4"
        case .mkv: return "matroska"
        case .avi: return "avi"
        case .webm: return "webm"
        }
    }
}

enum AspectRatioMode: String, CaseIterable {
    case original = "Авто"
    case ratio_16_9 = "16:9"
    case ratio_4_3 = "4:3"
    case ratio_1_1 = "1:1"
    case ratio_21_9 = "21:9"

    var targetRatio: Double {
        switch self {
        case .original: return 0 // Will use original ratio
        case .ratio_16_9: return 16.0 / 9.0
        case .ratio_4_3: return 4.0 / 3.0
        case .ratio_1_1: return 1.0
        case .ratio_21_9: return 21.0 / 9.0
        }
    }

    var displayName: String {
        rawValue
    }
}

struct ConversionSettings {
    var videoCodec: VideoCodec = .h264
    var audioCodec: AudioCodec = .aac
    var videoQuality: Double = 23.0 // CRF for H.264/H.265
    var audioBitrate: Int = 128 // kbps
    var outputFormat: OutputFormat = .mp4
    var outputDirectory: URL?
    var fileNameTemplate: String = "{original}_{quality}"
    var resolution: String = "Оригинал"
    var aspectRatioMode: AspectRatioMode = .original
    var customWidth: Int = 1920
    var customHeight: Int = 1080

    var customVideoArgs: String = ""
    var customAudioArgs: String = ""
    var customGlobalArgs: String = ""

    // Generate video filters for aspect ratio change
    func generateVideoFilters(inputWidth: Int, inputHeight: Int) -> String? {
        guard aspectRatioMode != .original else { return nil }

        // Validate input dimensions
        guard inputWidth > 0 && inputHeight > 0 else { return nil }

        print("DEBUG: generateVideoFilters called with inputWidth=\(inputWidth), inputHeight=\(inputHeight), aspectRatioMode=\(aspectRatioMode)")

        let inputRatio = Double(inputWidth) / Double(inputHeight)
        let targetRatio = aspectRatioMode.targetRatio

        // If ratios are already the same, no filter needed
        if abs(inputRatio - targetRatio) < 0.01 {
            return nil
        }

        // Calculate the scaled dimensions to fit the target aspect ratio
        var scaleWidth: Int
        var scaleHeight: Int

        // Compute target canvas (output) size that preserves most detail without upscaling too much
        var targetWidth: Int
        var targetHeight: Int

        if inputRatio > targetRatio {
            // Input is wider than target → expect top/bottom bars
            // Choose width based on the limiting dimension (avoid upscaling)
            targetWidth = min(inputWidth, Int(Double(inputHeight) * targetRatio))
            targetHeight = Int(Double(targetWidth) / targetRatio)
        } else {
            // Input is taller/narrower than target → expect side bars
            targetHeight = min(inputHeight, Int(Double(inputWidth) / targetRatio))
            targetWidth = Int(Double(targetHeight) * targetRatio)
        }

        // Ensure even dimensions (many codecs require even sizes)
        targetWidth = max(16, (targetWidth / 2) * 2)
        targetHeight = max(16, (targetHeight / 2) * 2)

        // Scale to fit inside target canvas preserving AR, then pad to exact canvas
        // This guarantees bars appear on correct sides without растягивания
        return "scale=\(targetWidth):\(targetHeight):force_original_aspect_ratio=decrease,pad=\(targetWidth):\(targetHeight):(ow-iw)/2:(oh-ih)/2:black,setdar=dar=\(targetRatio)"
    }
}

struct VideoFile: Identifiable {
    let id = UUID()
    let url: URL
    var status: ConversionStatus = .pending
    var progress: Double = 0.0
    var outputURL: URL?
    var errorMessage: String?

    // Metadata
    var duration: Double?
    var fileSize: Int64?
    var resolution: CGSize?
    var bitrate: Int?
    var codec: String?
    var thumbnail: NSImage?

    var fileName: String {
        url.lastPathComponent
    }

    var fileNameWithoutExtension: String {
        url.deletingPathExtension().lastPathComponent
    }

    var formattedDuration: String {
        guard let duration = duration else { return "--:--" }
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var formattedFileSize: String {
        guard let fileSize = fileSize else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var formattedBitrate: String {
        guard let bitrate = bitrate else { return "-- kb/s" }
        return "\(bitrate / 1000) kb/s"
    }
}
