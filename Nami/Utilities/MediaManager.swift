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
            let relativePath = "VoiceMemos/\(fileName)"
            // Background sync to iCloud
            if isICloudAvailable {
                Task.detached(priority: .background) {
                    await saveVoiceMemoToiCloud(relativePath: relativePath)
                }
            }
            return relativePath
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
    /// Uses NSFileCoordinator for reliable iCloud download instead of polling
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

        // Use NSFileCoordinator for reliable coordinated read
        // This blocks until the file is downloaded from iCloud
        nonisolated(unsafe) let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var resultImage: UIImage?

        // Run coordinated read on background to avoid blocking MainActor
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                coordinator.coordinate(readingItemAt: iCloudURL, options: [], error: &coordinatorError) { readURL in
                    if let data = try? Data(contentsOf: readURL),
                       let image = UIImage(data: data) {
                        resultImage = image
                        // Copy to local for future access
                        let localBase = AppConstants.sharedContainerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let localURL = localBase.appendingPathComponent(relativePath)
                        try? data.write(to: localURL)
                    }
                }
                continuation.resume()
            }
        }

        return resultImage
    }

    /// Sync all photos from iCloud to local (run on app launch)
    static func syncPhotosFromiCloud() async {
        guard let iCloudDir = iCloudPhotosDirectory else { return }
        let fm = FileManager.default

        // Collect URLs synchronously to avoid async iterator warning
        var fileURLs: [URL] = []
        if let enumerator = fm.enumerator(
            at: iCloudDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            while let obj = enumerator.nextObject() {
                if let url = obj as? URL { fileURLs.append(url) }
            }
        }

        for fileURL in fileURLs {
            let fileName = fileURL.lastPathComponent
            guard fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") || fileName.hasSuffix(".png") else { continue }

            let relativePath = "Photos/\(fileName)"
            let localBase = AppConstants.sharedContainerURL ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            let localURL = localBase.appendingPathComponent(relativePath)

            // Skip if already exists locally
            if fm.fileExists(atPath: localURL.path) { continue }

            // Start download and use coordinated read for reliability
            do {
                try fm.startDownloadingUbiquitousItem(at: fileURL)
                let coordinator = NSFileCoordinator()
                var coordError: NSError?
                coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordError) { readURL in
                    do {
                        try fm.copyItem(at: readURL, to: localURL)
                        print("Downloaded from iCloud: \(fileName)")
                    } catch {
                        print("iCloud copy error for \(fileName): \(error)")
                    }
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

        // Collect URLs synchronously to avoid async iterator warning
        var fileURLs: [URL] = []
        if let enumerator = fm.enumerator(
            at: localDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            while let obj = enumerator.nextObject() {
                if let url = obj as? URL { fileURLs.append(url) }
            }
        }

        for fileURL in fileURLs {
            let fileName = fileURL.lastPathComponent
            let relativePath = "Photos/\(fileName)"
            await savePhotoToiCloud(relativePath: relativePath)
        }
    }
}
