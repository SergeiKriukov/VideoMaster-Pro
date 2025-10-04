#!/usr/bin/env swift

import Foundation

func verifyFFmpegExecutable(at path: String) -> Bool {
    // In sandbox, we can't execute external processes, so just check if file exists and is executable
    let fileManager = FileManager.default

    // Check if file exists
    guard fileManager.fileExists(atPath: path) else {
        print("FFmpeg файл не найден по пути: \(path)")
        return false
    }

    // Check if file is executable
    do {
        let attributes = try fileManager.attributesOfItem(atPath: path)
        if let permissions = attributes[.posixPermissions] as? NSNumber {
            let perms = permissions.uint16Value
            // Check if owner has execute permission (0x49 = 73 = 0b001001001)
            if (perms & 0o100) != 0 { // Owner execute bit
                print("FFmpeg найден и является исполняемым по пути: \(path)")
                return true
            } else {
                print("FFmpeg по пути \(path) не является исполняемым")
            }
        }
    } catch {
        print("Ошибка при проверке атрибутов FFmpeg по пути \(path): \(error.localizedDescription)")
    }

    return false
}

func checkFFmpegInstallation() -> Bool {
    print("Проверка установки FFmpeg")

    // Check common installation locations for FFmpeg
    let possiblePaths = [
        "/usr/local/bin/ffmpeg",
        "/opt/homebrew/bin/ffmpeg",
        "/usr/bin/ffmpeg",
        "/opt/local/bin/ffmpeg", // MacPorts
        "/sw/bin/ffmpeg" // Fink
    ]

    for path in possiblePaths {
        print("Проверка пути: \(path)")

        if verifyFFmpegExecutable(at: path) {
            return true
        }
    }

    print("FFmpeg не найден ни по одному из стандартных путей")
    return false
}

// Test
let found = checkFFmpegInstallation()
print("Результат: FFmpeg \(found ? "найден" : "не найден")")
