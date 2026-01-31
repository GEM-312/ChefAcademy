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
    
    @State private var selectedTab: CustomizationTab = .skin
    
    enum CustomizationTab: String, CaseIterable {
        case skin = "Skin"
        case hair = "Hair"
        case color = "Color"
        case outfit = "Outfit"
        
        var icon: String {
            switch self {
            case .skin: return "hand.raised.fill"
            case .hair: return "comb.fill"
            case .color: return "paintpalette.fill"
            case .outfit: return "tshirt.fill"
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
            
            // Customization Tabs
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
                    case .skin:
                        SkinToneSelector(selectedSkin: $avatarModel.skinTone)
                    case .hair:
                        HairStyleSelector(selectedStyle: $avatarModel.hairStyle)
                    case .color:
                        HairColorSelector(selectedColor: $avatarModel.hairColor)
                    case .outfit:
                        OutfitSelector(selectedOutfit: $avatarModel.outfit)
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

// MARK: - Avatar Preview
struct AvatarPreviewView: View {
    @ObservedObject var avatarModel: AvatarModel
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.AppTheme.parchment)
                .frame(width: 220, height: 220)
            
            // Avatar representation (simplified - replace with actual illustrations)
            VStack(spacing: 0) {
                // Hair (top)
                HairView(style: avatarModel.hairStyle, color: avatarModel.hairColor)
                
                // Face
                ZStack {
                    // Head shape
                    Circle()
                        .fill(avatarModel.skinTone.color)
                        .frame(width: 120, height: 120)
                    
                    // Eyes
                    HStack(spacing: 25) {
                        Circle()
                            .fill(Color.AppTheme.darkBrown)
                            .frame(width: 12, height: 12)
                        Circle()
                            .fill(Color.AppTheme.darkBrown)
                            .frame(width: 12, height: 12)
                    }
                    .offset(y: -10)
                    
                    // Smile
                    Path { path in
                        path.addArc(
                            center: CGPoint(x: 60, y: 70),
                            radius: 20,
                            startAngle: .degrees(0),
                            endAngle: .degrees(180),
                            clockwise: false
                        )
                    }
                    .stroke(Color.AppTheme.darkBrown, lineWidth: 3)
                    .frame(width: 120, height: 120)
                    
                    // Blush
                    HStack(spacing: 60) {
                        Circle()
                            .fill(Color.pink.opacity(0.3))
                            .frame(width: 20, height: 15)
                        Circle()
                            .fill(Color.pink.opacity(0.3))
                            .frame(width: 20, height: 15)
                    }
                    .offset(y: 10)
                }
                
                // Outfit
                OutfitView(outfit: avatarModel.outfit)
                    .offset(y: -20)
            }
        }
    }
}

// MARK: - Hair View
struct HairView: View {
    let style: HairStyle
    let color: HairColor
    
    var body: some View {
        ZStack {
            switch style {
            case .short:
                Capsule()
                    .fill(color.color)
                    .frame(width: 100, height: 40)
                    .offset(y: 30)
                
            case .medium:
                Ellipse()
                    .fill(color.color)
                    .frame(width: 130, height: 60)
                    .offset(y: 25)
                
            case .long:
                VStack(spacing: -10) {
                    Ellipse()
                        .fill(color.color)
                        .frame(width: 130, height: 50)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(color.color)
                        .frame(width: 120, height: 80)
                }
                .offset(y: 15)
                
            case .curly:
                ZStack {
                    ForEach(0..<8) { i in
                        Circle()
                            .fill(color.color)
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
                        .fill(color.color)
                        .frame(width: 20, height: 80)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.color)
                        .frame(width: 20, height: 80)
                }
                .offset(y: 50)
                Ellipse()
                    .fill(color.color)
                    .frame(width: 110, height: 40)
                    .offset(y: 30)
                
            case .bun:
                VStack(spacing: -5) {
                    Circle()
                        .fill(color.color)
                        .frame(width: 50, height: 50)
                    Ellipse()
                        .fill(color.color)
                        .frame(width: 110, height: 35)
                }
                .offset(y: 10)
            }
        }
        .frame(height: 60)
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

// MARK: - Skin Tone Selector
struct SkinToneSelector: View {
    @Binding var selectedSkin: SkinTone
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Choose your skin tone")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
            
            HStack(spacing: AppSpacing.md) {
                ForEach(SkinTone.allCases) { tone in
                    Button(action: { selectedSkin = tone }) {
                        Circle()
                            .fill(tone.color)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(selectedSkin == tone ? Color.AppTheme.goldenWheat : Color.clear, lineWidth: 3)
                            )
                            .overlay(
                                selectedSkin == tone ?
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.AppTheme.darkBrown)
                                    .font(.system(size: 16, weight: .bold))
                                : nil
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
                                HairView(style: style, color: .brown)
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

// MARK: - Hair Color Selector
struct HairColorSelector: View {
    @Binding var selectedColor: HairColor
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Choose your hair color")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.md) {
                ForEach(HairColor.allCases) { color in
                    Button(action: { selectedColor = color }) {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(color.color)
                                .frame(width: 45, height: 45)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.AppTheme.goldenWheat : Color.clear, lineWidth: 3)
                                )
                                .overlay(
                                    selectedColor == color ?
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .font(.system(size: 14, weight: .bold))
                                    : nil
                                )
                            
                            Text(color.rawValue)
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
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
