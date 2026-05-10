import SwiftUI
import UIKit

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

        // Specialty colors — hex-backed until asset-cataloged for Dark Mode.
        // Use these instead of inline hex / raw system colors at call sites.
        static let pureWhite = Color(hex: "F7FAFC")               // chef hat white, near-white surfaces
        static let overlay = Color.black.opacity(0.4)             // modal dim behind dialogs
        static let sunYellow = Color(hex: "FFD54F")               // weather sun glow
        static let rainBlue = Color(hex: "4FC3F7")                // weather rain / storm drops
        static let autumnBrown = Color(hex: "8B4513")             // weather fall leaves
        static let frostBlue = Color(hex: "E3F2FD")               // weather winter sparkles
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
        static let captionLarge = Font.system(size: 14, weight: .regular, design: .rounded)
        static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
        static let microLarge = Font.system(size: 11, weight: .regular, design: .rounded)
        static let micro = Font.system(size: 10, weight: .regular, design: .rounded)

        // Special styles
        static let recipeStep = Font.system(size: 18, weight: .medium, design: .rounded)
        static let ingredientItem = Font.system(size: 16, weight: .regular, design: .rounded)
        static let timerDisplay = Font.system(size: 48, weight: .light, design: .rounded)

        // Escape hatch for one-off sizes/weights not covered by named tokens.
        // Always rounded — enforces design-system consistency.
        static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.system(size: size, weight: weight, design: .rounded)
        }
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
    static let iconSize: CGFloat = 24
    static let largeIconSize: CGFloat = 48

    // Corner radii — scale: pill (8) → small (12) → card (16) → large (20)
    static let pillCornerRadius: CGFloat = 8      // badges, chips, small buttons
    static let smallCornerRadius: CGFloat = 12    // inline cards, seed bags
    static let cardCornerRadius: CGFloat = 16     // standard cards (default)
    static let largeCornerRadius: CGFloat = 20    // hero cards, full-screen panels

    // Stroke widths — for borders and outlines
    static let strokeThin: CGFloat = 1
    static let strokeMedium: CGFloat = 2
    static let strokeBold: CGFloat = 3

    // PIN pad button — used by ParentPINEntryView, FamilySetupView, MigrationPINSetupView.
    // Three files each re-implemented this. Centralizing here.
    static let pinButtonWidth: CGFloat = 75
    static let pinButtonHeight: CGFloat = 55

    // Tab bar safe-area padding — keeps content above the floating tab bar.
    // Used by main-tab views (PlayLearnView, ProfileView, RecipeCardExample, etc.).
    static let tabBarClearance: CGFloat = 100

    // Hero image size for info cards (PantryInfoView, WeatherOverlayView sun glow).
    static let infoCardImageSize: CGFloat = 200
}

// MARK: - Animation Constants
// Centralized timing values — use these instead of inline magic numbers.
// See ANIMATIONS.md for the full rules on when to use each type.
enum AnimationConstants {
    // Springs — bouncy, natural feel for interactive elements
    static let springQuick   = Animation.spring(response: 0.3, dampingFraction: 0.6)   // buttons, bounces
    static let springMedium  = Animation.spring(response: 0.4, dampingFraction: 0.7)   // cards, dialogs
    static let springSlow    = Animation.spring(response: 0.5, dampingFraction: 0.7)   // large elements, reveals
    static let springBouncy  = Animation.spring(response: 0.3, dampingFraction: 0.5)   // celebrations, pose changes
    static let springSnappy  = Animation.spring(response: 0.2, dampingFraction: 0.5)   // snappy reactions (Pip throws, splashes)
    static let springTight   = Animation.spring(response: 0.3, dampingFraction: 0.4)   // tight bounce (inflate, scoring pop)

    // Easing — smooth transitions between states
    static let fadeQuick       = Animation.easeInOut(duration: 0.15)  // button press feedback
    static let fadeFast        = Animation.easeInOut(duration: 0.2)   // snappy toggles, subtle reveals
    static let fadeMedium      = Animation.easeInOut(duration: 0.3)   // content appear/disappear
    static let routeTransition = Animation.easeInOut(duration: 0.3)   // tab switches, route changes (alias of fadeMedium)
    static let revealSlow      = Animation.easeInOut(duration: 0.5)   // large element reveals
    static let pipTransition   = Animation.easeInOut(duration: 0.8)   // Pip pose/dialog transitions

    // Morph — card-to-detail matchedGeometryEffect transitions
    static let morphTransition = Animation.spring(response: 0.45, dampingFraction: 0.85)

    // Frame animation rates
    static let walkingFPS: Double = 8.0       // ~0.125s per frame (walking characters)
    static let wavingFPS: Double = 6.0        // ~0.167s per frame (idle wave loop)
    static let gameFPS: Double = 30.0         // ~0.033s per frame (one-shot game celebrations)
    static let walkSpeed: CGFloat = 54.0      // points per second (character movement)

    // Button press scales
    static let buttonPressScale: CGFloat = 0.97   // subtle squeeze (PrimaryButtonStyle)
    static let bouncyPressScale: CGFloat = 0.9     // bigger bounce (BouncyButtonStyle)

    // Kitchen cooking-flow timings — the fly/cleanup rhythm for pantry→counter→stove
    static let itemFlyDelay: TimeInterval = 0.55    // wait before fading the flying image
    static let itemFlyCleanup: TimeInterval = 0.7   // total step length before advancing
    static let stovePreRoll: TimeInterval = 1.2     // stove ignition delay before mini-game

    // Springs tuned for ingredient-fly animations (slightly slower than springMedium)
    static let springFly = Animation.spring(response: 0.6, dampingFraction: 0.7)

    // Quick fade used to pop the flying image after it reaches its target
    static let fadeFlyOut = Animation.easeOut(duration: 0.15)

    // Float loop — gentle idle bounce that runs forever.
    // Used by floating clouds, idle Pip breathing, breathing rings.
    static let floatLoop = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)

    // PIN-entry shake — fast bouncy shake when a wrong PIN is entered.
    // Lower damping than springQuick on purpose so the shake is visible.
    static let pinShake = Animation.spring(response: 0.2, dampingFraction: 0.3)

    // Weather change crossfade — used when WeatherOverlayView swaps overlays.
    static let weatherTransition = Animation.easeInOut(duration: 1.0)
}

// MARK: - Haptic Feedback
// Shared haptic helpers — use these instead of creating UIKit generators directly.
// Consolidated from CookingMiniGames, InsulinTetrisView, and ChopMiniGame.
enum Haptic {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Reusable View Modifiers

// Parchment card — the "reference" card style, used mainly in previews.
// Production code prefers the warmCream variant — see .softCard() below.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.md)
            .background(Color.AppTheme.parchment)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .shadow(color: Color.AppTheme.sepia.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// Soft card — the 80% case. Warm cream background, subtle shadow.
// Replaces inline .padding(...).background(warmCream).cornerRadius(...).shadow(...) chains.
struct SoftCardStyle: ViewModifier {
    var padding: CGFloat = AppSpacing.md
    var cornerRadius: CGFloat = AppSpacing.cardCornerRadius
    var showShadow: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(cornerRadius)
            .shadow(
                color: showShadow ? Color.AppTheme.sepia.opacity(0.1) : .clear,
                radius: showShadow ? 6 : 0,
                x: 0,
                y: showShadow ? 3 : 0
            )
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
            .scaleEffect(configuration.isPressed ? AnimationConstants.buttonPressScale : 1.0)
            .animation(AnimationConstants.fadeQuick, value: configuration.isPressed)
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
            .scaleEffect(configuration.isPressed ? AnimationConstants.buttonPressScale : 1.0)
            .animation(AnimationConstants.fadeQuick, value: configuration.isPressed)
    }
}

// Textured Button Style — wooden texture tinted with any AppTheme color.
// The wood grain stays visible through the color overlay (multiply blend).
// Text uses overlay blend so it looks embossed into the wood grain.
//
// TEACHING MOMENT: Blend Modes
// .multiply — darkens: wood grain shows through the tint color
// .overlay  — contrast: light areas brighten, dark areas darken
// This makes text look like it's carved/printed on the wood, not floating on top.
//
// Usage:
//   Button("Start") { }.texturedButton()                              — default sage, full width
//   Button("Cook!")  { }.texturedButton(tint: .goldenWheat)           — golden, full width
//   Button("Buy")   { }.buttonStyle(TexturedButtonStyle(height: 40))  — smaller button
//   Button("OK")    { }.buttonStyle(TexturedButtonStyle(fullWidth: false)) — hug content
//
struct TexturedButtonStyle: ButtonStyle {
    var tint: Color = Color.AppTheme.sage
    var textColor: Color = Color.AppTheme.cream
    var height: CGFloat = AppSpacing.buttonHeight
    var fullWidth: Bool = true
    var font: Font = .AppTheme.headline

    func makeBody(configuration: Configuration) -> some View {
        // Label drives the layout; texture fills behind via .background
        ZStack {
            // Label with overlay blend — text looks embossed into the wood
            configuration.label
                .font(font)
                .foregroundColor(textColor)
                .blendMode(.overlay)

            // Second pass for readability (overlay alone can lose contrast)
            configuration.label
                .font(font)
                .foregroundColor(textColor.opacity(0.7))
        }
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .frame(height: height)
        .padding(.horizontal, fullWidth ? 0 : AppSpacing.lg)
        .background(
            ZStack {
                // Wood grain texture — fills the capsule shape
                Image("button_backround")
                    .resizable()
                    .scaledToFill()

                // Color tint — multiply keeps the wood grain visible
                tint.opacity(0.45)
                    .blendMode(.multiply)
            }
        )
        .clipShape(Capsule())
        .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 4, x: 0, y: 2)
        .scaleEffect(configuration.isPressed ? AnimationConstants.bouncyPressScale : 1.0)
        .animation(AnimationConstants.fadeQuick, value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    /// Warm cream card — preferred for most production surfaces.
    /// Defaults: md padding, cardCornerRadius (16), subtle shadow.
    func softCard(
        padding: CGFloat = AppSpacing.md,
        cornerRadius: CGFloat = AppSpacing.cardCornerRadius,
        showShadow: Bool = true
    ) -> some View {
        modifier(SoftCardStyle(padding: padding, cornerRadius: cornerRadius, showShadow: showShadow))
    }

    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }

    func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }

    func texturedButton() -> some View {
        self.buttonStyle(TexturedButtonStyle())
    }

    func texturedButton(tint: Color) -> some View {
        self.buttonStyle(TexturedButtonStyle(tint: tint))
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
        .cornerRadius(AppSpacing.pillCornerRadius)
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

            // Textured Buttons — same image, different tints & sizes
            Button("Visit Garden") {}
                .texturedButton()

            Button("Let's Cook!") {}
                .texturedButton(tint: Color.AppTheme.goldenWheat)

            Button("Buy Seeds") {}
                .texturedButton(tint: Color.AppTheme.terracotta)

            // Smaller height
            Button("Body Buddy") {}
                .buttonStyle(TexturedButtonStyle(tint: Color.AppTheme.softOlive, height: 40))

            // Compact (hug content, not full width)
            HStack(spacing: AppSpacing.md) {
                Button("OK") {}
                    .buttonStyle(TexturedButtonStyle(height: 36, fullWidth: false, font: .AppTheme.subheadline))
                Button("Cancel") {}
                    .buttonStyle(TexturedButtonStyle(tint: Color.AppTheme.terracotta, height: 36, fullWidth: false, font: .AppTheme.subheadline))
            }

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
}
