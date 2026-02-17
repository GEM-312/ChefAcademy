//
//  AvatarCreatorView.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Avatar Creator View
struct AvatarCreatorView: View {
    @ObservedObject var avatarModel: AvatarModel
    @ObservedObject var onboardingManager: OnboardingManager

    @State private var selectedTab: CustomizationTab = .outfit

    enum CustomizationTab: String, CaseIterable {
        case outfit = "Outfit"
        case covering = "Covering"

        var icon: String {
            switch self {
            case .outfit: return "tshirt.fill"
            case .covering: return "person.crop.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: AppSpacing.xs) {
                Text("Create Your Chef!")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text("Make yourself look awesome")
                    .font(.AppTheme.subheadline)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .padding(.top, AppSpacing.lg)

            // Avatar Preview
            AvatarPreviewView(avatarModel: avatarModel)
                .frame(height: 280)
                .padding(.vertical, AppSpacing.md)

            // Customization Tabs — 2 tabs: Outfit, Covering
            HStack(spacing: AppSpacing.xs) {
                ForEach(CustomizationTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)

            // Customization Options
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    switch selectedTab {
                    case .outfit:
                        OutfitSelector(selectedOutfit: $avatarModel.outfit)
                    case .covering:
                        HeadCoveringSelector(selectedCovering: $avatarModel.headCovering)
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(Color.AppTheme.parchment)
            .cornerRadius(AppSpacing.cardCornerRadius, corners: [.topLeft, .topRight])

            // Navigation Buttons
            HStack(spacing: AppSpacing.md) {
                Button(action: {
                    onboardingManager.previousStep()
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                Button(action: {
                    onboardingManager.nextStep()
                }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(AppSpacing.md)
            .background(Color.AppTheme.cream)
        }
    }
}

// MARK: - Avatar Preview (uses actual character image from gender selection)
struct AvatarPreviewView: View {
    @ObservedObject var avatarModel: AvatarModel

    /// Last frame of the chosen gender's animation — the final pose
    private var characterImage: String {
        avatarModel.gender == .boy ? "boy_card_frame_28" : "girl_card_frame_15"
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.AppTheme.parchment)
                .frame(width: 220, height: 220)

            // Character image from chosen gender
            Image(characterImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .clipShape(Circle())
        }
    }
}

// MARK: - Hair View (no color — uses game's sepia/dark brown)
struct HairView: View {
    let style: HairStyle
    private let hairColor = Color.AppTheme.darkBrown.opacity(0.6)

    var body: some View {
        ZStack {
            switch style {
            case .short:
                Capsule()
                    .fill(hairColor)
                    .frame(width: 100, height: 40)
                    .offset(y: 30)

            case .medium:
                Ellipse()
                    .fill(hairColor)
                    .frame(width: 130, height: 60)
                    .offset(y: 25)

            case .long:
                VStack(spacing: -10) {
                    Ellipse()
                        .fill(hairColor)
                        .frame(width: 130, height: 50)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(hairColor)
                        .frame(width: 120, height: 80)
                }
                .offset(y: 15)

            case .curly:
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(hairColor)
                            .frame(width: 35, height: 35)
                            .offset(
                                x: CGFloat(cos(Double(i) * .pi / 4) * 45),
                                y: CGFloat(sin(Double(i) * .pi / 4) * 20) + 30
                            )
                    }
                }

            case .braids:
                HStack(spacing: 60) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hairColor)
                        .frame(width: 20, height: 80)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hairColor)
                        .frame(width: 20, height: 80)
                }
                .offset(y: 50)
                Ellipse()
                    .fill(hairColor)
                    .frame(width: 110, height: 40)
                    .offset(y: 30)

            case .bun:
                VStack(spacing: -5) {
                    Circle()
                        .fill(hairColor)
                        .frame(width: 50, height: 50)
                    Ellipse()
                        .fill(hairColor)
                        .frame(width: 110, height: 35)
                }
                .offset(y: 10)
            }
        }
        .frame(height: 60)
    }
}

// MARK: - Head Covering View
struct HeadCoveringView: View {
    let covering: HeadCovering

    var body: some View {
        switch covering {
        case .none:
            EmptyView()

        case .hijab:
            // Draped hijab shape wrapping around head
            ZStack {
                // Main drape
                Ellipse()
                    .fill(Color.AppTheme.sage.opacity(0.5))
                    .frame(width: 150, height: 70)
                    .offset(y: 20)
                // Side drape falling down
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.AppTheme.sage.opacity(0.5))
                    .frame(width: 130, height: 60)
                    .offset(y: 55)
            }

        case .kippah:
            // Small round cap on top of head
            Ellipse()
                .fill(Color.AppTheme.darkBrown.opacity(0.4))
                .frame(width: 50, height: 20)
                .offset(y: 10)

        case .turban:
            // Wrapped turban on top
            ZStack {
                Ellipse()
                    .fill(Color.AppTheme.goldenWheat.opacity(0.5))
                    .frame(width: 120, height: 50)
                    .offset(y: 18)
                // Wrap line
                Capsule()
                    .fill(Color.AppTheme.goldenWheat.opacity(0.7))
                    .frame(width: 100, height: 12)
                    .offset(y: 25)
            }
        }
    }
}

// MARK: - Outfit View
struct OutfitView: View {
    let outfit: Outfit

    var body: some View {
        ZStack {
            // Body/Torso
            RoundedRectangle(cornerRadius: 20)
                .fill(outfit.color)
                .frame(width: 100, height: 60)

            // Apron pocket (for apron outfits)
            if outfit != .chefWhite {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 25)
                    .offset(y: 10)
            }

            // Chef buttons (for chef coat)
            if outfit == .chefWhite {
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.AppTheme.darkBrown)
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.AppTheme.darkBrown)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.AppTheme.caption)
            }
            .foregroundColor(isSelected ? Color.AppTheme.cream : Color.AppTheme.sepia)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? Color.AppTheme.goldenWheat : Color.AppTheme.parchment)
            .cornerRadius(12)
        }
    }
}

// MARK: - Hair Style Selector
struct HairStyleSelector: View {
    @Binding var selectedStyle: HairStyle

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Choose your hairstyle")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.md) {
                ForEach(HairStyle.allCases) { style in
                    Button(action: { selectedStyle = style }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.AppTheme.parchment)
                                    .frame(width: 60, height: 60)

                                // Mini hair preview
                                HairView(style: style)
                                    .scaleEffect(0.4)
                            }

                            Text(style.rawValue)
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        .padding(AppSpacing.sm)
                        .background(selectedStyle == style ? Color.AppTheme.goldenWheat.opacity(0.3) : Color.clear)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedStyle == style ? Color.AppTheme.goldenWheat : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }
}

// MARK: - Head Covering Selector
struct HeadCoveringSelector: View {
    @Binding var selectedCovering: HeadCovering

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Head covering")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            Text("This also sets your dietary preference")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.md) {
                ForEach(HeadCovering.allCases) { covering in
                    Button(action: { selectedCovering = covering }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.AppTheme.parchment)
                                    .frame(width: 70, height: 70)

                                // Mini covering preview
                                HeadCoveringView(covering: covering)
                                    .scaleEffect(0.5)

                                // Show person icon for "none"
                                if covering == .none {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color.AppTheme.sepia.opacity(0.5))
                                }
                            }

                            Text(covering.rawValue)
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.darkBrown)

                            // Show dietary link
                            if covering.dietaryPreference != .none {
                                Text(covering.dietaryPreference.displayName)
                                    .font(.AppTheme.caption)
                                    .foregroundColor(Color.AppTheme.sage)
                            }
                        }
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(selectedCovering == covering ? Color.AppTheme.goldenWheat.opacity(0.3) : Color.clear)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedCovering == covering ? Color.AppTheme.goldenWheat : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }
}

// MARK: - Outfit Selector
struct OutfitSelector: View {
    @Binding var selectedOutfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Choose your outfit")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.md) {
                ForEach(Outfit.allCases) { outfit in
                    Button(action: { selectedOutfit = outfit }) {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.AppTheme.parchment)
                                    .frame(width: 70, height: 70)

                                OutfitView(outfit: outfit)
                                    .scaleEffect(0.7)
                            }

                            Text(outfit.rawValue)
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sepia)
                                .lineLimit(1)
                        }
                        .padding(AppSpacing.xs)
                        .background(selectedOutfit == outfit ? Color.AppTheme.goldenWheat.opacity(0.3) : Color.clear)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedOutfit == outfit ? Color.AppTheme.goldenWheat : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#Preview {
    AvatarCreatorView(
        avatarModel: AvatarModel(),
        onboardingManager: OnboardingManager()
    )
}
