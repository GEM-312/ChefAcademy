//
//  StationSignpostView.swift
//  ChefAcademy
//
//  A wooden signpost that stands in a scene (Garden, Kitchen, Shop) or sits
//  small in a page header (Body, Play) and points to the other places. With
//  the bottom tab bar gone (Oct 18 2026), the Home map and these signposts are
//  the only way around, so every one includes Home. The artwork has three
//  blank arrow boards; the place names are drawn on them here, and each board
//  is a button that switches place.
//

import SwiftUI

struct StationSignpostView: View {
    /// The places on the boards, top board to bottom board (up to three).
    let destinations: [MainTabView.Tab]
    @Binding var selectedTab: MainTabView.Tab
    /// The smaller version for a page header (Body, Play) instead of a scene.
    var inHeader: Bool = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Width ÷ height of the signpost artwork (700 × 1112).
    private static let artAspect: CGFloat = 700.0 / 1112.0

    /// Centre of each board's blank middle, as fractions of the artwork.
    /// Top points left, middle points right, bottom points left.
    private static let boardCenters: [CGPoint] = [
        CGPoint(x: 0.48, y: 0.20),
        CGPoint(x: 0.53, y: 0.42),
        CGPoint(x: 0.47, y: 0.625),
    ]
    /// Tappable size of one board, as fractions of the artwork.
    private static let boardSize = CGSize(width: 0.80, height: 0.18)
    /// How much of a board's width the name may use (keeps it off the arrow tip and nails).
    private static let labelWidth: CGFloat = 0.58

    var body: some View {
        let height = inHeader
            ? AdaptiveCardSize.signpostHeaderHeight(for: sizeClass)
            : AdaptiveCardSize.signpostHeight(for: sizeClass)
        let labelSize = inHeader
            ? AdaptiveCardSize.signpostHeaderLabelSize(for: sizeClass)
            : AdaptiveCardSize.signpostLabelSize(for: sizeClass)
        let width = height * Self.artAspect

        Image("signpost")
            .resizable()
            .frame(width: width, height: height)
            .overlay {
                ForEach(Array(destinations.prefix(Self.boardCenters.count).enumerated()), id: \.element) { index, tab in
                    let center = Self.boardCenters[index]
                    Button {
                        Haptic.impact(.light)
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.AppTheme.rounded(size: labelSize, weight: .bold))
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(width: width * Self.labelWidth)
                            .frame(width: width * Self.boardSize.width, height: height * Self.boardSize.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .accessibilityLabel("Go to \(tab.rawValue)")
                    .position(x: width * center.x, y: height * center.y)
                }
            }
    }
}

#Preview {
    StationSignpostView(destinations: [.home, .shop, .kitchen], selectedTab: .constant(.garden))
        .padding()
        .background(Color.AppTheme.cream)
}
