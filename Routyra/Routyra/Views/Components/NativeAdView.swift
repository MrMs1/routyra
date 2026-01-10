//
//  NativeAdView.swift
//  Routyra
//
//  Native ad view component for Google Mobile Ads.
//

import GoogleMobileAds
import SwiftUI

struct NativeAdViewWrapper: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context _: Context) -> GoogleMobileAds.NativeAdView {
        let adView = createNativeAdView()
        adView.nativeAd = nativeAd
        return adView
    }

    func updateUIView(_ uiView: GoogleMobileAds.NativeAdView, context _: Context) {
        uiView.nativeAd = nativeAd
        configureVisibility(for: uiView, with: nativeAd)
    }

    private func configureVisibility(for adView: GoogleMobileAds.NativeAdView, with ad: NativeAd) {
        if let iconView = adView.iconView {
            iconView.isHidden = ad.icon == nil
        }

        if let headlineView = adView.headlineView {
            headlineView.isHidden = ad.headline == nil || ad.headline?.isEmpty == true
        }

        if let bodyView = adView.bodyView {
            bodyView.isHidden = ad.body == nil || ad.body?.isEmpty == true
        }

        if let advertiserView = adView.advertiserView {
            advertiserView.isHidden = ad.advertiser == nil || ad.advertiser?.isEmpty == true
        }

        if let ctaView = adView.callToActionView {
            ctaView.isHidden = ad.callToAction == nil || ad.callToAction?.isEmpty == true
        }
    }

    private func createNativeAdView() -> GoogleMobileAds.NativeAdView {
        let adView = GoogleMobileAds.NativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false

        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        headlineLabel.numberOfLines = 3
        headlineLabel.lineBreakMode = .byTruncatingTail
        headlineLabel.textColor = UIColor(AppColors.textPrimary)
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel

        // Ad badge
        let adBadge = UILabel()
        adBadge.text = L10n.tr("ad_badge")
        adBadge.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        adBadge.textColor = .white
        adBadge.backgroundColor = UIColor(AppColors.accentBlue)
        adBadge.textAlignment = .center
        adBadge.layer.cornerRadius = 3
        adBadge.clipsToBounds = true
        adBadge.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(adBadge)
        adView.advertiserView = adBadge

        // Media view
        let mediaView = MediaView()
        mediaView.contentMode = .scaleAspectFit
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = 8
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(mediaView)
        adView.mediaView = mediaView

        // Body (hidden for compact layout)
        let bodyLabel = UILabel()
        bodyLabel.font = UIFont.systemFont(ofSize: 11)
        bodyLabel.textColor = UIColor(AppColors.textSecondary)
        bodyLabel.numberOfLines = 1
        bodyLabel.isHidden = true
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel

        // CTA button
        let ctaButton = UIButton(type: .system)
        ctaButton.setTitle(L10n.tr("ad_cta_button"), for: .normal)
        ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.backgroundColor = UIColor(AppColors.accentBlue)
        ctaButton.layer.cornerRadius = 6
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(ctaButton)
        adView.callToActionView = ctaButton

        // Icon (hidden for compact layout)
        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 8
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(iconImageView)
        adView.iconView = iconImageView

        // Layout constraints
        NSLayoutConstraint.activate([
            // Fixed height for ad view
            adView.heightAnchor.constraint(equalToConstant: 130),

            // Icon (hidden)
            iconImageView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            iconImageView.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 0),
            iconImageView.heightAnchor.constraint(equalToConstant: 0),

            // Media view (left side)
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 3),
            mediaView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 5),
            mediaView.widthAnchor.constraint(equalToConstant: 215),
            mediaView.heightAnchor.constraint(equalToConstant: 120),

            // Headline (right of media)
            headlineLabel.leadingAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: 8),
            headlineLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 4),
            headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),

            // Ad badge
            adBadge.leadingAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: 8),
            adBadge.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 8),
            adBadge.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            adBadge.heightAnchor.constraint(equalToConstant: 32),

            // CTA button
            ctaButton.leadingAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: 8),
            ctaButton.topAnchor.constraint(equalTo: adBadge.bottomAnchor, constant: 8),
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            ctaButton.heightAnchor.constraint(equalToConstant: 32),

            // Body (hidden)
            bodyLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
            bodyLabel.widthAnchor.constraint(equalToConstant: 0),
            bodyLabel.heightAnchor.constraint(equalToConstant: 0)
        ])

        return adView
    }
}

// MARK: - SwiftUI Card Wrapper

struct NativeAdCardView: View {
    let nativeAd: NativeAd

    var body: some View {
        NativeAdViewWrapper(nativeAd: nativeAd)
            .frame(height: 130)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
    }
}
