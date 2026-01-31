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

    /// Pip video size for message cards
    static func pipMessage(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .compact ? 70 : 90
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
            .font(.system(size: sizeClass == .compact ? compactSize : regularSize))
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
                RoundedRectangle(cornerRadius: 12)
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.3))
                    .frame(height: 100)
            }
        }
        .padding()
    }
    .background(Color.gray.opacity(0.1))
    .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch)"))
}
