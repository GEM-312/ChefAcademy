//
//  BackgroundDownloadHandler.swift
//  AssetPackDownloader
//
//  Created by Pollak Marina on 4/27/26.
//

import BackgroundAssets
import ExtensionFoundation
import StoreKit

@main
struct DownloaderExtension: StoreDownloaderExtension {
    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        // Use this method to filter out asset packs that the system would otherwise download automatically. You can also remove this method entirely if you just want to rely on the default download behavior.
        return true
    }
}
