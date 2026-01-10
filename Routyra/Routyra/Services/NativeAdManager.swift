//
//  NativeAdManager.swift
//  Routyra
//
//  Native ad management for Google Mobile Ads.
//

import Combine
import Foundation
import GoogleMobileAds
import SwiftUI

// MARK: - Item or Ad Type

/// Represents either a list item or an ad
enum ItemOrAd<Item: Identifiable>: Identifiable {
    case item(Item)
    case ad(NativeAd, index: Int)

    var id: String {
        switch self {
        case let .item(item):
            return "item_\(item.id)"
        case let .ad(_, index):
            return "ad_\(index)"
        }
    }
}

class NativeAdManager: NSObject, ObservableObject {
    // Production ad unit ID
    static let nativeAdUnitID = "ca-app-pub-1341591553764994/7603178255"

    @Published var nativeAds: [NativeAd] = []
    @Published var isLoading = false

    private var adLoader: AdLoader?

    override init() {
        super.init()
    }

    /// Load multiple native ads at once
    func loadNativeAds(count: Int = 3) {
        isLoading = true

        // Clear old ads
        nativeAds.removeAll()

        // Cleanup existing loader
        adLoader?.delegate = nil

        let options = NativeAdMediaAdLoaderOptions()
        options.mediaAspectRatio = .landscape

        let videoOptions = VideoOptions()
        videoOptions.shouldStartMuted = true

        let multipleAdsOptions = MultipleAdsAdLoaderOptions()
        multipleAdsOptions.numberOfAds = count

        adLoader = AdLoader(
            adUnitID: Self.nativeAdUnitID,
            rootViewController: getRootViewController(),
            adTypes: [.native],
            options: [options, videoOptions, multipleAdsOptions]
        )
        adLoader?.delegate = self

        let request = Request()
        adLoader?.load(request)
    }

    /// Calculate required ad count based on item count
    /// - Parameters:
    ///   - itemCount: Number of items
    ///   - interval: Ad insertion interval (default: 3)
    ///   - maxAds: Maximum number of ads (default: 3)
    /// - Returns: Required ad count
    static func calculateAdCount(for itemCount: Int, interval: Int = 3, maxAds: Int = 3) -> Int {
        if itemCount == 0 {
            return 0
        }
        // For 3 or fewer items, we show 1 ad at bottom
        if itemCount <= interval {
            return 1
        }
        // Otherwise, one ad per interval
        return min(itemCount / interval, maxAds)
    }

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController
        else {
            return nil
        }
        return rootViewController
    }
}

// MARK: - AdLoader Delegate

extension NativeAdManager: NativeAdLoaderDelegate {
    func adLoader(_: AdLoader, didReceive nativeAd: NativeAd) {
        nativeAds.append(nativeAd)
    }

    func adLoader(_: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("Native ad load failed: \(error.localizedDescription)")
        isLoading = false
    }

    func adLoaderDidFinishLoading(_: AdLoader) {
        isLoading = false
    }
}
