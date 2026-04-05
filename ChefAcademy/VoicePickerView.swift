//
//  VoicePickerView.swift
//  ChefAcademy
//
//  Voice selection screen — kids/parents pick how Pip sounds.
//  Shows free Apple voices (with preview) and premium ElevenLabs voice.
//  Guides users to Settings to download better voices if needed.
//
//  TEACHING MOMENT: This screen serves two goals:
//    1. Let users pick a voice they like (engagement)
//    2. Upsell the premium Pip voice (revenue for subscription)
//  The "try it" button for premium creates desire before the paywall.
//

import SwiftUI
import AVFoundation

// MARK: - Voice Picker View

struct VoicePickerView: View {

    @ObservedObject private var pipVoice = PipVoice.shared
    @Environment(\.dismiss) private var dismiss

    @State private var previewingVoiceID: String?
    @State private var showSettingsGuide = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // MARK: - Header
                    pipHeader

                    // MARK: - Two simple options
                    VStack(spacing: AppSpacing.md) {

                        // Option 1: Read Text (free, silent)
                        VoiceOptionCard(
                            icon: "text.bubble.fill",
                            title: "Read Text",
                            subtitle: "Read Pip's words on screen — no voice",
                            color: Color.AppTheme.sage,
                            isSelected: pipVoice.voiceMode == .readText
                        ) {
                            pipVoice.voiceMode = .readText
                            pipVoice.stop()
                        }

                        // Option 2: Pip's Voice (subscription)
                        VoiceOptionCard(
                            icon: "waveform.circle.fill",
                            title: "Pip's Voice",
                            subtitle: pipVoice.hasSubscription
                                ? "Pip talks with a real character voice!"
                                : "Custom Pip character voice — Pip Plus $3.99/mo",
                            color: Color.AppTheme.goldenWheat,
                            isSelected: pipVoice.voiceMode == .elevenLabs,
                            isLocked: !pipVoice.hasSubscription
                        ) {
                            if pipVoice.hasSubscription {
                                pipVoice.voiceMode = .elevenLabs
                            }
                        }

                        // Preview button for ElevenLabs
                        if pipVoice.hasSubscription || true { // always show preview
                            Button(action: {
                                pipVoice.previewElevenLabsVoice()
                            }) {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: pipVoice.isSpeaking ? "speaker.wave.3.fill" : "play.circle.fill")
                                        .symbolEffect(.pulse, isActive: pipVoice.isSpeaking)
                                    Text("Preview Pip's Voice")
                                }
                                .font(.AppTheme.subheadline)
                                .foregroundColor(Color.AppTheme.goldenWheat)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(AppSpacing.md)
            }
            .background(Color.AppTheme.cream)
            .navigationTitle("Pip's Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.AppTheme.sage)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Pip Header

    private var pipHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            Image("pip_waving")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)

            Text("Pick how I sound!")
                .font(.AppTheme.title2)
                .foregroundColor(Color.AppTheme.darkBrown)

            Text("Tap a voice to hear a preview")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .padding(.top, AppSpacing.md)
    }

    // MARK: - Premium Voice Section

    private var premiumVoiceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Pip's Special Voice", systemImage: "star.fill")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.goldenWheat)

            VoiceCard(
                name: "Pip's Character Voice",
                quality: "Custom AI Voice",
                qualityColor: Color.AppTheme.goldenWheat,
                isSelected: pipVoice.voiceMode == .elevenLabs,
                isLocked: !pipVoice.hasSubscription,
                onTap: {
                    if pipVoice.hasSubscription {
                        pipVoice.voiceMode = .elevenLabs
                    }
                },
                onPreview: {
                    previewingVoiceID = "elevenlabs"
                    pipVoice.previewElevenLabsVoice()
                },
                isPreviewing: previewingVoiceID == "elevenlabs" && pipVoice.isSpeaking
            )

            if !pipVoice.hasSubscription {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                    Text("Upgrade to Pip Plus — $3.99/month")
                        .font(.AppTheme.caption)
                }
                .foregroundColor(Color.AppTheme.goldenWheat)
                .padding(.leading, AppSpacing.xs)
            }
        }
    }

}

// MARK: - Voice Card

struct VoiceCard: View {
    let name: String
    let quality: String
    let qualityColor: Color
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void
    let onPreview: () -> Void
    let isPreviewing: Bool

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Voice info
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.AppTheme.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text(quality)
                    .font(.AppTheme.caption)
                    .foregroundColor(qualityColor)
            }

            Spacer()

            // Preview button
            Button(action: onPreview) {
                Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color.AppTheme.sage)
                    .symbolEffect(.pulse, isActive: isPreviewing)
            }
            .buttonStyle(.plain)

            // Selection / lock indicator
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.AppTheme.goldenWheat)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.AppTheme.sage)
            } else {
                Circle()
                    .stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 2)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(AppSpacing.md)
        .background(
            isSelected
                ? Color.AppTheme.sage.opacity(0.1)
                : Color.AppTheme.warmCream
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.AppTheme.sage : Color.clear,
                    lineWidth: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { if !isLocked { onTap() } }
    }
}

// MARK: - Voice Option Card (Simple 2-option picker)

struct VoiceOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isSelected: Bool
    var isLocked: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: { if !isLocked { onTap() } }) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)

                    Text(subtitle)
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sepia)
                }

                Spacer()

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color)
                } else {
                    Circle()
                        .stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(AppSpacing.md)
            .background(isSelected ? color.opacity(0.1) : Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Guide Sheet
//
// TEACHING MOMENT: Since we can't deep-link to the voice download page
// (App Store rejection risk), we show step-by-step instructions with
// a button that opens the general Settings app.
//

struct SettingsGuideSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let steps = [
        ("1", "Open Settings", "gear"),
        ("2", "Tap Accessibility", "figure.stand"),
        ("3", "Tap Read & Speak", "text.bubble"),
        ("4", "Tap Voices", "speaker.wave.2"),
        ("5", "Tap English", "globe"),
        ("6", "Download a voice (tap the cloud icon)", "icloud.and.arrow.down")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Text("How to get a better voice for Pip")
                        .font(.AppTheme.title3)
                        .foregroundColor(Color.AppTheme.darkBrown)
                        .padding(.top, AppSpacing.lg)

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        ForEach(steps, id: \.0) { step in
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: step.2)
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.AppTheme.sage)
                                    .frame(width: 36, height: 36)
                                    .background(Color.AppTheme.sage.opacity(0.15))
                                    .cornerRadius(8)

                                Text(step.1)
                                    .font(.AppTheme.body)
                                    .foregroundColor(Color.AppTheme.darkBrown)

                                Spacer()
                            }
                        }
                    }
                    .padding(AppSpacing.md)

                    Text("Look for \"Samantha\" or \"Ava\" — they sound the best!")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sepia)
                        .italic()
                        .multilineTextAlignment(.center)

                    Button(action: openSettings) {
                        Label("Open Settings", systemImage: "gear")
                            .font(.AppTheme.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(Color.AppTheme.sage)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, AppSpacing.md)

                    Text("Come back after downloading — Pip will automatically use the new voice!")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sage)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(AppSpacing.md)
            }
            .background(Color.AppTheme.cream)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.AppTheme.sage)
                }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    VoicePickerView()
}
