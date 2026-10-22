//
//  GardenJobBubble.swift
//  ChefAcademy
//
//  A bubble floating over a garden spot that needs the kid (Oct 22 2026), the
//  way farm games show a need: a picture, not words. Tool jobs show the tool
//  to take from the fence (fork = loosen, shovel = plant, can = water); hand
//  jobs show the trouble (a weed, a bug). Harvest keeps its own sparkle and
//  "Harvest!" look in PlotView.
//
//  GardenView draws the bubbles on the map, not inside the rows: the rows are
//  scaled down to about a third (back) or half (front) on iPhone, which is
//  why the spots' own labels are too small to read.
//

import SwiftUI

struct GardenJobBubble: View {
    enum Icon: Equatable {
        case tool(GardenTool)
        case emoji(String)
    }

    let icon: Icon
    let size: CGFloat

    @State private var bob = false

    // Proportions of the bubble, relative to its circle's size
    private static let tailWidth: CGFloat = 0.3
    private static let tailHeight: CGFloat = 0.2
    private static let picturePadding: CGFloat = 0.18
    private static let emojiSize: CGFloat = 0.55

    /// What a spot needs, or nil when there's nothing to show (growing, ready
    /// for harvest). Empty soil is marked only while `showsSoilJob`: until the
    /// kid has done that job once, and never while visiting a sibling. Water,
    /// weeds and bugs always show; they turn up while the kid is away.
    static func icon(for plot: GardenPlot, showsSoilJob: Bool) -> Icon? {
        switch plot.state {
        case .empty:           return showsSoilJob ? .tool(plot.soilLoosened ? .shovel : .fork) : nil
        case .needsWater:      return .tool(.wateringCan)
        case .needsWeeding:    return .emoji("🌿")
        case .hasBugs:         return .emoji("🐛")
        case .growing, .ready: return nil
        }
    }

    /// Full height (circle + tail), so the caller can rest the tail on the spot.
    static func height(for size: CGFloat) -> CGFloat {
        size * (1 + tailHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.AppTheme.warmCream)
                Circle().stroke(Color.AppTheme.sepia.opacity(0.5), lineWidth: AppSpacing.strokeThin)
                picture.padding(size * Self.picturePadding)
            }
            .frame(width: size, height: size)

            Triangle()
                .fill(Color.AppTheme.warmCream)
                .frame(width: size * Self.tailWidth, height: size * Self.tailHeight)
                .rotationEffect(.degrees(180))   // points down at the spot
        }
        .shadow(color: Color.AppTheme.sepia.opacity(0.25), radius: AppSpacing.xxs)
        .offset(y: bob ? -AppSpacing.xxs : 0)
        .allowsHitTesting(false)                 // taps reach the spot below
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(AnimationConstants.floatLoopFast) { bob = true }
        }
    }

    @ViewBuilder
    private var picture: some View {
        switch icon {
        case .tool(let tool):
            Image(tool.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .emoji(let emoji):
            Text(emoji)
                .font(.AppTheme.rounded(size: size * Self.emojiSize))
        }
    }
}
