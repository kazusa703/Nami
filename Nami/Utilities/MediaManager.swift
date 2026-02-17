//
//  MediaManager.swift
//  Nami
//
//  写真・ボイスメモのファイル管理
//

import UIKit

/// メディアファイル（写真・ボイスメモ）の保存・読み込み・削除を管理する
enum MediaManager {

    // MARK: - ディレクトリ

    /// 写真保存ディレクトリ
    static var photosDirectory: URL {
        let base = AppConstants.sharedContainerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// ボイスメモ保存ディレクトリ
    static var voiceDirectory: URL {
        let base = AppConstants.sharedContainerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("VoiceMemos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 写真

    /// 写真を保存してApp Group内の相対パスを返す
    static func savePhoto(_ image: UIImage) -> String? {
        let fileName = "photo_\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        do {
            try data.write(to: fileURL)
            return "Photos/\(fileName)"
        } catch {
            print("写真保存エラー: \(error)")
            return nil
        }
    }

    // MARK: - ボイスメモ

    /// ボイスメモファイルを移動して相対パスを返す
    static func saveVoiceMemo(from sourceURL: URL) -> String? {
        let fileName = "voice_\(UUID().uuidString).m4a"
        let destURL = voiceDirectory.appendingPathComponent(fileName)

        do {
            // ソースが一時ディレクトリにある場合はコピー
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return "VoiceMemos/\(fileName)"
        } catch {
            print("ボイスメモ保存エラー: \(error)")
            return nil
        }
    }

    // MARK: - ファイル解決

    /// 相対パスからフルURLを解決する
    static func resolveURL(for relativePath: String) -> URL? {
        let base = AppConstants.sharedContainerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// 写真をUIImageとして読み込む
    static func loadPhoto(at relativePath: String) -> UIImage? {
        guard let url = resolveURL(for: relativePath),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - 削除

    /// メディアファイルを削除する
    static func deleteMedia(at relativePath: String) {
        guard let url = resolveURL(for: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
