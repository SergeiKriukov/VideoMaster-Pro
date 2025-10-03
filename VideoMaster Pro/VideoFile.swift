//
//  VideoFile.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import Foundation
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
    var aspectRatio: String = "16:9"
    var customWidth: Int = 1920
    var customHeight: Int = 1080

    var customVideoArgs: String = ""
    var customAudioArgs: String = ""
    var customGlobalArgs: String = ""
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
