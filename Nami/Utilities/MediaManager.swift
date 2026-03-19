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

    /// 写真を保存してApp Group内の相対パスを返す（自動iCloudアップロード付き）
    static func savePhoto(_ image: UIImage) -> String? {
        let fileName = "photo_\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        do {
            try data.write(to: fileURL)
            let relativePath = "Photos/\(fileName)"
            // Background sync to iCloud
            if isICloudAvailable {
                Task.detached(priority: .background) {
                    await savePhotoToiCloud(relativePath: relativePath)
                }
            }
            return relativePath
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

    // MARK: - iCloud Documents Sync

    /// iCloud Documents container URL for photos
    static var iCloudPhotosDirectory: URL? {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: AppConstants.iCloudContainerIdentifier
        ) else { return nil }
        let dir = containerURL.appendingPathComponent("Documents/Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// iCloud Documents container URL for voice memos
    static var iCloudVoiceDirectory: URL? {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: AppConstants.iCloudContainerIdentifier
        ) else { return nil }
        let dir = containerURL.appendingPathComponent("Documents/VoiceMemos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Whether iCloud Documents is available
    static var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Copy a photo to iCloud Documents (background-safe)
    static func savePhotoToiCloud(relativePath: String) async {
        guard let localURL = resolveURL(for: relativePath) else { return }

        let fileName = (relativePath as NSString).lastPathComponent
        guard let iCloudDir = iCloudPhotosDirectory else { return }
        let iCloudURL = iCloudDir.appendingPathComponent(fileName)

        // Skip if already exists in iCloud
        guard !FileManager.default.fileExists(atPath: iCloudURL.path) else { return }

        do {
            try FileManager.default.copyItem(at: localURL, to: iCloudURL)
            print("Photo synced to iCloud: \(fileName)")
        } catch {
            print("iCloud photo sync error: \(error)")
        }
    }

    /// Copy a voice memo to iCloud Documents (background-safe)
    static func saveVoiceMemoToiCloud(relativePath: String) async {
        guard let localURL = resolveURL(for: relativePath) else { return }

        let fileName = (relativePath as NSString).lastPathComponent
        guard let iCloudDir = iCloudVoiceDirectory else { return }
        let iCloudURL = iCloudDir.appendingPathComponent(fileName)

        guard !FileManager.default.fileExists(atPath: iCloudURL.path) else { return }

        do {
            try FileManager.default.copyItem(at: localURL, to: iCloudURL)
            print("Voice memo synced to iCloud: \(fileName)")
        } catch {
            print("iCloud voice memo sync error: \(error)")
        }
    }

    /// Load a photo from iCloud if not available locally
    static func loadPhotoWithiCloudFallback(at relativePath: String) async -> UIImage? {
        // Try local first
        if let image = loadPhoto(at: relativePath) {
            return image
        }

        // Try iCloud fallback
        let fileName = (relativePath as NSString).lastPathComponent
        guard let iCloudDir = iCloudPhotosDirectory else { return nil }
        let iCloudURL = iCloudDir.appendingPathComponent(fileName)

        // Start download if needed
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: iCloudURL)
        } catch {
            return nil
        }

        // Wait briefly for download (up to 5 seconds)
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: iCloudURL.path),
               let data = try? Data(contentsOf: iCloudURL),
               let image = UIImage(data: data) {
                // Copy to local for future access
                let localBase = AppConstants.sharedContainerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let localURL = localBase.appendingPathComponent(relativePath)
                try? data.write(to: localURL)
                return image
            }
            try? await Task.sleep(for: .milliseconds(500))
        }

        return nil
    }

    /// Sync all photos from iCloud to local (run on app launch)
    static func syncPhotosFromiCloud() async {
        guard let iCloudDir = iCloudPhotosDirectory else { return }
        let fm = FileManager.default

        // Enumerate iCloud photos directory
        guard let enumerator = fm.enumerator(
            at: iCloudDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent
            guard fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") || fileName.hasSuffix(".png") else { continue }

            let relativePath = "Photos/\(fileName)"
            let localBase = AppConstants.sharedContainerURL ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            let localURL = localBase.appendingPathComponent(relativePath)

            // Skip if already exists locally
            if fm.fileExists(atPath: localURL.path) { continue }

            // Start download if needed
            do {
                try fm.startDownloadingUbiquitousItem(at: fileURL)
                // Give it a moment to download
                try? await Task.sleep(for: .milliseconds(200))
                if fm.fileExists(atPath: fileURL.path) {
                    try fm.copyItem(at: fileURL, to: localURL)
                    print("Downloaded from iCloud: \(fileName)")
                }
            } catch {
                print("iCloud download error for \(fileName): \(error)")
            }
        }
    }

    /// Upload all local photos to iCloud (run on app launch)
    static func syncPhotosToiCloud() async {
        guard iCloudPhotosDirectory != nil else { return }
        let fm = FileManager.default
        let localDir = photosDirectory

        guard let enumerator = fm.enumerator(
            at: localDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent
            let relativePath = "Photos/\(fileName)"
            await savePhotoToiCloud(relativePath: relativePath)
        }
    }
}
