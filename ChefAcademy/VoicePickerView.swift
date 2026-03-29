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

                    // MARK: - Premium Voice (Pip Plus)
                    premiumVoiceSection

                    // MARK: - Free Voices
                    freeVoicesSection

                    // MARK: - Download Better Voices
                    if pipVoice.onlyDefaultVoicesAvailable {
                        downloadPrompt
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
        .sheet(isPresented: $showSettingsGuide) {
            SettingsGuideSheet()
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

    // MARK: - Free Voices Section

    private var freeVoicesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Free Voices", systemImage: "speaker.wave.2.fill")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            ForEach(pipVoice.availableEnglishVoices.prefix(8), id: \.identifier) { voice in
                VoiceCard(
                    name: voice.name,
                    quality: qualityLabel(voice.quality),
                    qualityColor: qualityColor(voice.quality),
                    isSelected: pipVoice.voiceMode == .appleTTS
                        && pipVoice.selectedAppleVoiceID == voice.identifier,
                    isLocked: false,
                    onTap: {
                        pipVoice.voiceMode = .appleTTS
                        pipVoice.selectedAppleVoiceID = voice.identifier
                    },
                    onPreview: {
                        previewingVoiceID = voice.identifier
                        pipVoice.previewAppleVoice(voice)
                    },
                    isPreviewing: previewingVoiceID == voice.identifier && pipVoice.isSpeaking
                )
            }
        }
    }

    // MARK: - Download Better Voices Prompt
    //
    // TEACHING MOMENT: We can't trigger voice downloads programmatically.
    // But we CAN guide the user with friendly instructions + a button
    // that opens Settings. When they come back after downloading,
    // availableVoicesDidChangeNotification fires and we auto-update.
    //

    private var downloadPrompt: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(Color.AppTheme.sage)

            Text("Want Pip to sound even better?")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            Text("Ask a grown-up to download a better voice in Settings!")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
                .multilineTextAlignment(.center)

            Button(action: { showSettingsGuide = true }) {
                Label("Show Me How", systemImage: "gear")
                    .font(.AppTheme.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.AppTheme.sage)
                    .cornerRadius(24)
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Standard"
        }
    }

    private func qualityColor(_ quality: AVSpeechSynthesisVoiceQuality) -> Color {
        switch quality {
        case .premium: return Color.AppTheme.goldenWheat
        case .enhanced: return Color.AppTheme.sage
        default: return Color.AppTheme.sepia
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
        ("3", "Tap Spoken Content", "text.bubble"),
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
