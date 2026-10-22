//
//  AdaptiveLayout.swift
//  ChefAcademy
//
//  Responsive layout helpers for iPhone and iPad.
//  Centers content with max width on larger screens.
//
//  SWIFTUI LESSON: Responsive Design
//  ----------------------------------
//  - Use GeometryReader to get screen size
//  - Use @Environment(\.horizontalSizeClass) to detect iPhone vs iPad
//  - Create adaptive containers that work on all devices
//

import SwiftUI

// MARK: - Device Detection

struct DeviceInfo {
    /// Check if running on iPad
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Check if running on iPhone
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}

// MARK: - Adaptive Container
//
// A container that:
// - Uses full width on iPhone
// - Centers with max width on iPad
// - Adds appropriate padding for each device
//

struct AdaptiveContainer<Content: View>: View {
    let maxWidth: CGFloat
    let content: Content

    init(maxWidth: CGFloat = 700, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            let isCompact = horizontalSizeClass == .compact
            let contentWidth = isCompact ? geometry.size.width : min(geometry.size.width, maxWidth)

            HStack {
                Spacer(minLength: 0)

                content
                    .frame(width: contentWidth)

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Adaptive Scroll View
//
// A ScrollView that centers content on larger screens
//

struct AdaptiveScrollView<Content: View>: View {
    let maxWidth: CGFloat
    let showsIndicators: Bool
    let content: Content

    init(
        maxWidth: CGFloat = 700,
        showsIndicators: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.maxWidth = maxWidth
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            let isCompact = horizontalSizeClass == .compact
            let contentWidth = isCompact ? geometry.size.width : min(geometry.size.width - 64, maxWidth)
            let horizontalPadding = (geometry.size.width - contentWidth) / 2

            ScrollView(showsIndicators: showsIndicators) {
                content
                    .frame(maxWidth: contentWidth)
                    .padding(.horizontal, max(horizontalPadding, 0))
            }
        }
    }
}

// MARK: - Adaptive Values
//
// Helper to get different values based on device/size class
//

struct AdaptiveValue {
    @Environment(\.horizontalSizeClass) static var sizeClass

    /// Returns different values for compact (iPhone) vs regular (iPad) size classes
    static func value<T>(compact: T, regular: T, sizeClass: UserInterfaceSizeClass?) -> T {
        sizeClass == .compact ? compact : regular
    }
}

// MARK: - Adaptive Spacing
//
// Spacing that scales for iPad
//

struct AdaptiveSpacing {
    static func padding(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? AppSpacing.md : AppSpacing.lg
    }

    static func cardSpacing(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? AppSpacing.md : AppSpacing.lg
    }

    static func sectionSpacing(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? AppSpacing.lg : AppSpacing.xl
    }
}

// MARK: - Adaptive Card Size

struct AdaptiveCardSize {
    /// Quick action card size
    static func quickAction(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 90 : 120
    }

    /// Quick action icon size
    static func quickActionIcon(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 60 : 80
    }

    /// Quick action emoji size
    static func quickActionEmoji(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 30 : 40
    }

    /// Avatar preview size
    static func avatarPreview(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 50 : 70
    }

    /// Pip video size for message cards (home screen)
    static func pipMessage(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 140 : 280
    }

    /// Pip size for onboarding/welcome screens (large)
    static func pipOnboarding(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 220 : 320
    }

    /// Pip size for "ready to start" screen (medium)
    static func pipReadyScreen(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 100 : 160
    }

    /// Pip border width
    static func pipBorderWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 3 : 5
    }

    /// Walking Pip sprite size in the kitchen scene. iPad matches the Garden
    /// Pip (~232 pt tall, Marina Oct 22); iPhone keeps 108.
    static func pipKitchenWalking(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 108 : 370
    }

    /// Extra scale for the Home map's location sprites. The narrow iPhone map
    /// draws them small, so they're 20% bigger there; iPad keeps the art's size.
    static func homeStationScale(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 1.2 : 1.0
    }

    /// Walking Pip's frame on the Garden map. The walk art fills 62% of it, so
    /// he stands ~116 / 232 pt tall: the size of the old panel Pip (Marina, Oct 22).
    static func pipGardenWalking(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 185 : 370
    }

    /// Height of the tool picture in the Garden's "in hand" badge (map corner)
    static func gardenToolBadge(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 40 : 60
    }

    /// Circle of the job bubble floating over a garden spot that needs the kid
    /// (GardenJobBubble). Same size on every row, near or far.
    static func gardenJobBubble(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 30 : 48
    }

    /// Widest the garden wheelbarrow's harvest card gets (HarvestCartCard)
    static func harvestCardWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 340 : 480
    }

    /// Veggie picture in the harvest card's grid
    static func harvestCardVeggie(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 56 : 80
    }

    // Cooking on iPad (Marina, Oct 22): the screens are designed at iPhone
    // size, and the iPad zooms each one to fit its space (zoomedToFit). Games
    // scale content to a design canvas this way; a fixed 1.5× still left the
    // iPad 13" mini-games filling only ~40% of their area.

    /// Design canvas of a cooking mini-game: iPhone width, tall enough for the
    /// tallest game (chop, ~420). On an iPad 13" in portrait this zooms 2×.
    static let cookingGameCanvas = CGSize(width: 420, height: 480)

    /// Design canvas of the cooking completion screen (the whole screen: the
    /// rewards block plus its buttons). About 1.35× on an iPad 13" in portrait,
    /// so the rewards fill ~80% of the space above the buttons.
    static let cookingCompletionCanvas = CGSize(width: 420, height: 985)

    /// Most the cooking screens zoom, so the text inside stays a sane size.
    static let cookingMaxZoom: CGFloat = 2

    /// How much an iPhone-sized design `canvas` zooms to fill `space`: the
    /// smaller of the width and height ratios, kept between 1× and `maxScale`.
    /// iPhone (compact) always stays 1×.
    static func fitScale(_ space: CGSize, canvas: CGSize, maxScale: CGFloat,
                         for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        guard sizeClass != .compact else { return 1 }
        let fit = min(space.width / canvas.width, space.height / canvas.height)
        return min(maxScale, max(1, fit))
    }

    /// Pip beside his how-to tip under a cooking mini-game. iPad: easy to spot
    /// (~8% of the screen height, Marina, Oct 22).
    static func cookingPipTip(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 44 : 110
    }

    /// Floating speech bubble width beside walking Pip
    static func pipBubbleWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 200 : 280
    }

    /// Height of the Ask Pip button in the floating bubble. On iPhone it's a small
    /// pill that hugs its text; on iPad it keeps the full-size button.
    static func pipBubbleButtonHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 32 : AppSpacing.buttonHeight
    }

    // MARK: Kitchen Scene Tokens
    // Sizes for the tappable spots on the kitchen map (Counter / Stove / Pantry),
    // the flying ingredient image, and the small badge images on recipe cards.

    /// Outer "ring" circle diameter on a kitchen spot button (pulses when active).
    static func kitchenSpotRing(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 50 : 70
    }

    /// Inner filled circle diameter behind the spot icon.
    static func kitchenSpotInner(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 40 : 56
    }

    /// How far left of a kitchen station Pip stops on the floor, so he points
    /// up at it without standing on its button (iPad grew with the bigger Pip).
    static func kitchenPipStationGap(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 40 : 130
    }

    /// Height of the wooden signpost that points to the other places (Garden / Kitchen / Shop).
    static func signpostHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 200 : 320
    }

    /// Font size of the place names written on the signpost boards.
    static func signpostLabelSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 15 : 24
    }

    /// The smaller signpost in a page header (Body, Play), beside the title.
    static func signpostHeaderHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 160 : 240
    }

    /// Place names on the smaller header signpost.
    static func signpostHeaderLabelSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 12 : 18
    }

    /// Height of the Today's Recipe easel, a cut-out prop standing on the kitchen floor.
    static func kitchenTodayProp(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 130 : 220
    }

    /// SF Symbol size for the icon inside a kitchen spot.
    static func kitchenSpotIcon(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 18 : 24
    }

    /// Font size for the numeric count badge on a kitchen spot.
    static func kitchenBadgeFontSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 10 : 12
    }

    /// Offset magnitude for the count badge relative to the spot center (x / -y).
    static func kitchenBadgeOffset(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 16 : 22
    }

    /// Font size for the label text under each kitchen spot (Counter / Stove / Pantry).
    static func kitchenSpotLabelSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 10 : 13
    }

    /// SF Symbol size used by icon-only buttons in the kitchen header.
    static func kitchenHeaderIconSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 20 : 24
    }

    /// Square size of the flying ingredient image between pantry / counter / stove.
    /// iPad is 50% bigger than it was (100 → 150, Marina, Oct 22).
    static func kitchenFlyingItem(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 80 : 150
    }

    /// Square size of the small ingredient images stacked on the counter.
    /// iPad is 50% bigger than it was (60 → 90, Marina, Oct 22).
    static func kitchenGatheredItem(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 50 : 90
    }

    /// Square image size for "Ready to Cook!" recipe rows in the bottom panel.
    static func kitchenReadyImage(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 60 : 80
    }

    /// Square image size for "Almost Ready!" recipe rows in the bottom panel.
    static func kitchenAlmostImage(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 44 : 60
    }

    /// Width of the pantry staple badge (shown in the "On the Counter" row).
    static func pantryBadgeWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 70 : 110
    }

    /// Square image size inside the pantry staple badge.
    static func pantryBadgeImage(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 30 : 40
    }

    /// Font size for the staple name inside the pantry badge.
    static func pantryBadgeLabelSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 9 : 13
    }
}

// MARK: - Adaptive Font Modifier
//
// Scales fonts slightly larger on iPad
//

struct AdaptiveFontModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) var sizeClass
    let compactSize: CGFloat
    let regularSize: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.AppTheme.rounded(size: sizeClass == .compact ? compactSize : regularSize))
    }
}

extension View {
    func adaptiveFont(compact: CGFloat, regular: CGFloat) -> some View {
        modifier(AdaptiveFontModifier(compactSize: compact, regularSize: regular))
    }
}

// MARK: - Max Width Container Modifier

struct MaxWidthModifier: ViewModifier {
    let maxWidth: CGFloat
    @Environment(\.horizontalSizeClass) var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .compact {
            content
        } else {
            HStack {
                Spacer(minLength: 0)
                content
                    .frame(maxWidth: maxWidth)
                Spacer(minLength: 0)
            }
        }
    }
}

extension View {
    /// Centers content with a max width on larger screens
    func maxWidth(_ width: CGFloat) -> some View {
        modifier(MaxWidthModifier(maxWidth: width))
    }
}

// MARK: - Zoom
//
// `scaleEffect` alone only magnifies the drawing: the view keeps its old size
// in the layout, so it spills over its neighbours. ZoomLayout also gives it the
// room. The content lays out in the space divided by `scale`, then is drawn
// `scale`× bigger, so it fills exactly that space (a full-width bar still spans
// the screen) and everything inside, offsets and touches too, grows together.

struct ZoomLayout: Layout {
    let scale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let size = content.sizeThatFits(ProposedViewSize(
            width: proposal.width.map { $0 / scale },
            height: proposal.height.map { $0 / scale }
        ))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(width: bounds.width / scale, height: bounds.height / scale)
        )
    }
}

extension View {
    /// Draws this view `scale`× bigger and makes room for it (see ZoomLayout).
    func zoomed(by scale: CGFloat) -> some View {
        ZoomLayout(scale: scale) { scaleEffect(scale) }
    }

    /// Zooms this view to fill all the space it's given, as if that space were
    /// the iPhone-sized design `canvas` (AdaptiveCardSize.fitScale). On iPhone
    /// the view is left exactly as it is.
    func zoomedToFit(canvas: CGSize, maxScale: CGFloat) -> some View {
        modifier(ZoomToFitModifier(canvas: canvas, maxScale: maxScale))
    }
}

private struct ZoomToFitModifier: ViewModifier {
    let canvas: CGSize
    let maxScale: CGFloat
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .compact {
            content
        } else {
            GeometryReader { geo in
                content
                    .zoomed(by: AdaptiveCardSize.fitScale(geo.size, canvas: canvas,
                                                          maxScale: maxScale, for: sizeClass))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

// MARK: - Trailing Fade
//
// A non-interactive gradient on the right edge that signals "more content
// is over here" — gives kids an at-rest scroll cue on horizontal carousels
// where iOS's default scrollbar only appears mid-gesture. Defaults to the
// app cream background; pass `color:` if your scroll sits on warmCream or
// another surface. The fade is hit-test transparent.

struct TrailingFadeModifier: ViewModifier {
    var color: Color = Color.AppTheme.cream
    var width: CGFloat = AppSpacing.xl

    func body(content: Content) -> some View {
        content.overlay(alignment: .trailing) {
            LinearGradient(
                colors: [color.opacity(0), color],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Adds a soft gradient on the trailing edge as an at-rest cue that the
    /// horizontal carousel has more content to scroll. See TrailingFadeModifier.
    func trailingFade(color: Color = Color.AppTheme.cream, width: CGFloat = AppSpacing.xl) -> some View {
        modifier(TrailingFadeModifier(color: color, width: width))
    }
}

// MARK: - Adaptive Grid
//
// Grid that shows more columns on iPad
//

struct AdaptiveGrid<Content: View>: View {
    let minItemWidth: CGFloat
    let spacing: CGFloat
    let content: Content

    init(
        minItemWidth: CGFloat = 100,
        spacing: CGFloat = AppSpacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minItemWidth), spacing: spacing)],
            spacing: spacing
        ) {
            content
        }
    }
}

// MARK: - Preview

#Preview("Adaptive Container - iPhone") {
    AdaptiveScrollView {
        VStack(spacing: 20) {
            Text("This is centered content")
                .font(.title)

            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: AppSpacing.smallCornerRadius)
                    .fill(Color.blue.opacity(0.3))
                    .frame(height: 100)
            }
        }
        .padding()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Adaptive Container - iPad") {
    AdaptiveScrollView(maxWidth: 600) {
        VStack(spacing: 20) {
            Text("This is centered content")
                .font(.title)

            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: AppSpacing.smallCornerRadius)
                    .fill(Color.blue.opacity(0.3))
                    .frame(height: 100)
            }
        }
        .padding()
    }
    .background(Color.gray.opacity(0.1))
}
