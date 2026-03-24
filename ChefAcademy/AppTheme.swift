import SwiftUI

// MARK: - Little Chef Academy Style Guide
// Inspired by vintage botanical illustrations with a whimsical, handcrafted feel

// MARK: - Color Palette (Asset Catalog backed — supports Dark Mode)
extension Color {
    struct AppTheme {
        // Primary Colors (defined in Assets.xcassets/AppColors/)
        static let cream = Color("AppColors/cream")                // Backgrounds
        static let warmCream = Color("AppColors/warmCream")        // Lighter backgrounds
        static let parchment = Color("AppColors/parchment")        // Cards, surfaces

        // Text & Line Colors
        static let sepia = Color("AppColors/sepia")                // Primary text
        static let darkBrown = Color("AppColors/darkBrown")        // Headlines, emphasis
        static let lightSepia = Color("AppColors/lightSepia")      // Secondary text

        // Accent Colors
        static let sage = Color("AppColors/sage")                  // Nature accents, success
        static let goldenWheat = Color("AppColors/goldenWheat")    // Highlights, buttons, rewards
        static let softOlive = Color("AppColors/softOlive")        // Secondary accents
        static let terracotta = Color("AppColors/terracotta")      // Warnings, heat indicators
        static let warmKhaki = Color("AppColors/warmKhaki")        // Warm accent (from avatar style)

        // Functional Colors (aliases to accent colors)
        static let easyLevel = Color("AppColors/softOlive")       // Easy recipes
        static let mediumLevel = Color("AppColors/goldenWheat")   // Medium recipes
        static let hardLevel = Color("AppColors/terracotta")      // Hard recipes (needs adult help)
    }
}

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography
extension Font {
    struct AppTheme {
        // Using system fonts with rounded design for friendly feel
        // You can replace with custom fonts like "Quicksand" or "Nunito" later
        
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .medium, design: .rounded)
        
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .rounded)
        
        static let callout = Font.system(size: 16, weight: .regular, design: .rounded)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .rounded)
        static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
        
        // Special styles
        static let recipeStep = Font.system(size: 18, weight: .medium, design: .rounded)
        static let ingredientItem = Font.system(size: 16, weight: .regular, design: .rounded)
        static let timerDisplay = Font.system(size: 48, weight: .light, design: .rounded)
    }
}

// MARK: - Spacing & Sizing
struct AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    
    // Kid-friendly tap targets (minimum 44pt for accessibility)
    static let minTapTarget: CGFloat = 44
    static let buttonHeight: CGFloat = 52
    static let cardCornerRadius: CGFloat = 16
    static let iconSize: CGFloat = 24
    static let largeIconSize: CGFloat = 48
}

// MARK: - Reusable View Modifiers

// Card Style Modifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.md)
            .background(Color.AppTheme.parchment)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .shadow(color: Color.AppTheme.sepia.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.AppTheme.headline)
            .foregroundColor(Color.AppTheme.cream)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.buttonHeight)
            .background(Color.AppTheme.goldenWheat)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.AppTheme.headline)
            .foregroundColor(Color.AppTheme.darkBrown)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.buttonHeight)
            .background(Color.AppTheme.parchment)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
}

// MARK: - Difficulty Badge Component
struct DifficultyBadge: View {
    enum Level: String {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Needs Help"
        
        var color: Color {
            switch self {
            case .easy: return Color.AppTheme.easyLevel
            case .medium: return Color.AppTheme.mediumLevel
            case .hard: return Color.AppTheme.hardLevel
            }
        }
        
        var icon: String {
            switch self {
            case .easy: return "leaf.fill"
            case .medium: return "flame.fill"
            case .hard: return "person.2.fill"
            }
        }
    }
    
    let level: Level
    
    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: level.icon)
                .font(.caption)
            Text(level.rawValue)
                .font(.AppTheme.caption)
        }
        .foregroundColor(Color.AppTheme.cream)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background(level.color)
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: AppSpacing.lg) {
            // Colors Preview
            Text("Little Chef Academy")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)
            
            Text("Learn to cook healthy & delicious meals!")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
            
            // Buttons
            Button("Start Cooking") {}
                .primaryButton()
            
            Button("Browse Recipes") {}
                .secondaryButton()
            
            // Difficulty Badges
            HStack(spacing: AppSpacing.sm) {
                DifficultyBadge(level: .easy)
                DifficultyBadge(level: .medium)
                DifficultyBadge(level: .hard)
            }
            
            // Sample Card
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Rainbow Veggie Wrap")
                    .font(.AppTheme.title3)
                    .foregroundColor(Color.AppTheme.darkBrown)
                
                Text("A colorful, crunchy wrap packed with fresh vegetables")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                
                HStack {
                    DifficultyBadge(level: .easy)
                    Spacer()
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "clock")
                        Text("15 min")
                    }
                    .font(.AppTheme.footnote)
                    .foregroundColor(Color.AppTheme.lightSepia)
                }
            }
            .cardStyle()
        }
        .padding(AppSpacing.md)
    }
    .background(Color.AppTheme.cream)
}//
//  AppTheme.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

