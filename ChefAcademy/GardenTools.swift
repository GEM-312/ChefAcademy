//
//  GardenTools.swift
//  ChefAcademy
//
//  The garden tools on the fence by the gate: shovel, fork and watering can.
//  Tap a tool to pick it up, tap it again (or the "in hand" badge) to put it
//  back. The watering can is filled by tapping it on the rack, a pump per tap.
//
//  Jobs need their tool: fork = loosen an empty spot's hard soil, shovel =
//  plant (in loosened soil) + harvest, a full can = water (one fill waters one
//  plant). Weeds and bugs are by hand. Trying a job without its tool makes
//  that tool glow on the rack (GardenView.showToolHint) and the job is
//  remembered: taking that tool flies it to the spot and finishes the job.
//
//  The tools are cut out of the garden art (Oct 22 2026) and drawn exactly
//  where they were painted; garden_map_background is the plate without them.
//

import SwiftUI

// MARK: - Garden Tool

enum GardenTool: CaseIterable {
    case shovel, fork, wateringCan

    var imageName: String {
        switch self {
        case .shovel:      return "garden_tool_shovel"
        case .fork:        return "garden_tool_fork"
        case .wateringCan: return "garden_tool_watering_can"
        }
    }

    var displayName: String {
        switch self {
        case .shovel:      return "Shovel"
        case .fork:        return "Fork"
        case .wateringCan: return "Watering can"
        }
    }

    /// What Pip says the first time the kid needs this tool.
    var pipLesson: String {
        switch self {
        case .fork:        return "This soil is hard! Take the fork and loosen it, so seeds can grow."
        case .shovel:      return "Take the shovel! It plants seeds, and digs up veggies when they're ready."
        case .wateringCan: return "A thirsty plant! Tap the watering can to fill it, then tap the plant to water it."
        }
    }

    /// Garden scene spot where Pip stands (feet) to point at this tool.
    var pipSpotID: String {
        switch self {
        case .shovel:      return "pipShovel"
        case .fork:        return "pipFork"
        case .wateringCan: return "pipCan"
        }
    }

    /// Pip explains each tool once per player.
    var tutorial: PipTutorial {
        switch self {
        case .fork:        return .gardenFork
        case .shovel:      return .gardenShovel
        case .wateringCan: return .gardenWateringCan
        }
    }

    /// Where the tool hangs on the fence, as a fraction of the garden map.
    /// Measured from the cut-out art on the 1296×2304 canvas.
    var rackFrame: CGRect {
        switch self {
        case .shovel:      return CGRect(x: 0.0880, y: 0.7595, width: 0.0586, height: 0.1155)
        case .fork:        return CGRect(x: 0.1543, y: 0.7600, width: 0.0494, height: 0.1128)
        case .wateringCan: return CGRect(x: 0.1968, y: 0.7830, width: 0.1790, height: 0.0890)
        }
    }
}

// MARK: - Tool Rack (on the map)

/// The three tools on the fence. Lives inside the map's GeometryReader overlay.
struct GardenToolRack: View {
    let mapWidth: CGFloat
    let mapHeight: CGFloat
    @Binding var heldTool: GardenTool?
    @Binding var canFill: Double
    /// The tool the kid needs right now (they tried a job without it); it glows.
    var hintTool: GardenTool? = nil

    var body: some View {
        ZStack {
            ForEach(GardenTool.allCases, id: \.self) { tool in
                let f = frame(for: tool)
                rackTool(tool, frame: f)
                    .position(x: f.midX, y: f.midY)
            }

            if heldTool == .wateringCan && canFill < 1 {
                fillMeter
            }
        }
    }

    private func frame(for tool: GardenTool) -> CGRect {
        let r = tool.rackFrame
        return CGRect(x: r.minX * mapWidth, y: r.minY * mapHeight,
                      width: r.width * mapWidth, height: r.height * mapHeight)
    }

    @ViewBuilder
    private func rackTool(_ tool: GardenTool, frame f: CGRect) -> some View {
        let picture = Image(tool.imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: f.width, height: f.height)
            // While it's in the kid's hand, a faint ghost marks where it goes back
            .opacity(heldTool == tool ? 0.25 : 1)
            .scaleEffect(hintTool == tool ? AnimationConstants.toolHintScale : 1)
            .shadow(color: Color.AppTheme.goldenWheat.opacity(hintTool == tool ? 0.9 : 0),
                    radius: AppSpacing.xs)
            .contentShape(Rectangle())
            .accessibilityLabel(tool.displayName)
            .accessibilityAddTraits(.isButton)

        if tool == .wateringCan {
            picture.onTapGesture { pumpCan() }
        } else {
            picture.onTapGesture { toggle(tool) }
        }
    }

    // MARK: Fill meter (above the can while it fills)

    private var fillMeter: some View {
        let f = frame(for: .wateringCan)
        return VStack(spacing: AppSpacing.xxs) {
            Text("Tap to fill!")
                .font(.AppTheme.micro.bold())
                .foregroundColor(Color.AppTheme.sage)
            WaterLevelBar(level: canFill)
                .frame(width: f.width, height: AppSpacing.xs)
        }
        .padding(AppSpacing.xxs)
        .background(Color.AppTheme.warmCream.opacity(0.9))
        .cornerRadius(AppSpacing.pillCornerRadius)
        .position(x: f.midX, y: f.minY - AppSpacing.md)
        .allowsHitTesting(false)
    }

    // MARK: Actions

    private func toggle(_ tool: GardenTool) {
        Haptic.selection()
        withAnimation(AnimationConstants.springQuick) {
            heldTool = (heldTool == tool) ? nil : tool
        }
    }

    /// Each tap pumps one step of water in (the first tap also picks the can
    /// up); a tap on a full can in hand puts it back. Taps, not a hold: the
    /// map scrolls, and a held finger drifts until the ScrollView steals it.
    private func pumpCan() {
        if heldTool == .wateringCan && canFill >= 1 {
            toggle(.wateringCan)
            return
        }
        if heldTool != .wateringCan { toggle(.wateringCan) }
        // Snap to whole pumps so three thirds make exactly 1 (no 0.9999 can)
        let pumps = Double(AnimationConstants.canPumpsToFill)
        withAnimation(AnimationConstants.springQuick) {
            canFill = min(1, ((canFill * pumps).rounded() + 1) / pumps)
        }
        if canFill >= 1 { Haptic.notify(.success) } else { Haptic.impact(.light) }
    }
}

// MARK: - Flying Tool (fence → spot)

/// A tool flying from its place on the fence to a garden spot, tilting into
/// the soil as it lands. A fresh view per flight (GardenView gives it an .id),
/// so onAppear always starts it at the fence.
struct GardenToolFlight: View {
    let tool: GardenTool
    let size: CGSize
    let from: CGPoint
    let to: CGPoint

    @State private var arrived = false

    var body: some View {
        Image(tool.imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(arrived ? AnimationConstants.toolDigAngle : 0), anchor: .bottom)
            .position(arrived ? to : from)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(AnimationConstants.springFly) { arrived = true }
            }
    }
}

// MARK: - "In Hand" Badge (map corner)

/// Shows the tool the kid is holding; tapping it puts the tool back.
struct GardenHeldToolBadge: View {
    let tool: GardenTool
    let canFill: Double
    let onPutBack: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let size = AdaptiveCardSize.gardenToolBadge(for: sizeClass)
        Button(action: onPutBack) {
            VStack(spacing: AppSpacing.xxs) {
                Image(tool.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                if tool == .wateringCan {
                    WaterLevelBar(level: canFill)
                        .frame(width: size, height: AppSpacing.xs)
                }
            }
            .softCard(padding: AppSpacing.xs, cornerRadius: AppSpacing.smallCornerRadius)
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel("Put back the \(tool.displayName.lowercased())")
    }
}

// MARK: - Water Level Bar

/// How full the watering can is: 0 = empty, 1 = full.
private struct WaterLevelBar: View {
    let level: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.AppTheme.parchment)
                Capsule()
                    .fill(Color.AppTheme.rainBlue)
                    .frame(width: geo.size.width * level)
            }
        }
    }
}
