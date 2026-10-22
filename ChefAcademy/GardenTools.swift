//
//  GardenTools.swift
//  ChefAcademy
//
//  The garden tools on the fence by the gate: shovel, fork and watering can.
//  Tap a tool to pick it up, tap it again (or the "in hand" badge) to put it
//  back. The watering can is filled by holding it on the rack.
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

    @State private var isPressingCan = false
    @State private var fillTask: Task<Void, Never>?

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
        .onDisappear { fillTask?.cancel() }
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
            .contentShape(Rectangle())
            .accessibilityLabel(tool.displayName)
            .accessibilityAddTraits(.isButton)

        if tool == .wateringCan {
            // Press = pick up (if needed) and fill while held; a full can in
            // hand goes back with a tap. onChanged fires on every finger move,
            // so isPressingCan makes it run once per press.
            picture.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressCan() }
                    .onEnded { _ in releaseCan() }
            )
        } else {
            picture.onTapGesture { toggle(tool) }
        }
    }

    // MARK: Fill meter (above the can while it fills)

    private var fillMeter: some View {
        let f = frame(for: .wateringCan)
        return VStack(spacing: AppSpacing.xxs) {
            Text(isPressingCan ? "Filling..." : "Hold to fill!")
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
        fillTask?.cancel()
        withAnimation(AnimationConstants.springQuick) {
            heldTool = (heldTool == tool) ? nil : tool
        }
    }

    private func pressCan() {
        guard !isPressingCan else { return }
        isPressingCan = true
        if heldTool == .wateringCan && canFill >= 1 {
            toggle(.wateringCan)                 // full can in hand: tap puts it back
            return
        }
        if heldTool != .wateringCan { toggle(.wateringCan) }
        startFilling()
    }

    private func releaseCan() {
        isPressingCan = false
        fillTask?.cancel()                       // a half-filled can keeps its water
    }

    private func startFilling() {
        fillTask?.cancel()
        fillTask = Task { @MainActor in
            let tick = 0.05
            while canFill < 1 {
                try? await Task.sleep(for: .seconds(tick))
                guard !Task.isCancelled else { return }
                canFill = min(1, canFill + tick / AnimationConstants.canFillDuration)
            }
            Haptic.notify(.success)
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
