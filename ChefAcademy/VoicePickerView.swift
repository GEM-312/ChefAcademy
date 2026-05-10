//
//  VoicePickerView.swift
//  ChefAcademy
//
//  Voice selection screen — two honest options:
//    1. Read Text (free, silent — Pip's words on screen)
//    2. Pip's Voice (Pip Plus subscription — ElevenLabs character voice)
//
//  Preview button lets the user hear Pip's real voice before subscribing.
//

import SwiftUI

// MARK: - Voice Picker View

struct VoicePickerView: View {

    @ObservedObject private var pipVoice = PipVoice.shared
    @Environment(\.dismiss) private var dismiss

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

                        // Preview button — lets users hear Pip's voice before subscribing
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
        PipHeaderStack(
            title: "How should I talk?",
            subtitle: "Read silently, or hear my voice with Pip Plus",
            pose: .pointsUpLeft,
            clipToCircle: false
        )
        .padding(.top, AppSpacing.md)
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
                    .font(.AppTheme.title)
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
                        .font(.AppTheme.callout)
                        .foregroundColor(Color.AppTheme.goldenWheat)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.AppTheme.rounded(size: 24))
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

// MARK: - Preview

#Preview {
    VoicePickerView()
}
