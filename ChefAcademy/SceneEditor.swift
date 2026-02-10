//
//  SceneEditor.swift
//  ChefAcademy
//
//  A Theatre.js-style visual editor for positioning items on a scene map.
//  Toggle edit mode → drag items around → see exact % positions in real time.
//  Copy the printed positions to code when you're happy with the layout.
//
//  USAGE:
//  1. Set `editMode = true` in your view
//  2. Items become draggable with position labels
//  3. A floating panel shows all positions as code-ready values
//  4. Drag items to where they look right
//  5. Copy the printed values into your code
//  6. Set `editMode = false` when done
//
//  Works with ANY map image — garden, kitchen, or future scenes.
//

import SwiftUI

// MARK: - Scene Item (a draggable point on the map)

struct SceneItem: Identifiable {
    let id: String       // e.g. "counter", "stove", "pip"
    let label: String    // Display name
    let icon: String     // SF Symbol or emoji
    var xPercent: CGFloat // 0.0 - 1.0 (percentage of map width)
    var yPercent: CGFloat // 0.0 - 1.0 (percentage of map height)
}

// MARK: - Scene Editor Overlay

/// Overlay this on your map image inside a GeometryReader.
/// Pass in the map size and a binding to your scene items.
///
/// Example:
/// ```
/// Image("bg_kitchen")
///     .overlay(
///         GeometryReader { geo in
///             SceneEditorOverlay(
///                 mapWidth: geo.size.width,
///                 mapHeight: geo.size.height,
///                 items: $sceneItems,
///                 editMode: editMode
///             )
///         }
///     )
/// ```

struct SceneEditorOverlay: View {
    let mapWidth: CGFloat
    let mapHeight: CGFloat
    @Binding var items: [SceneItem]
    let editMode: Bool

    var body: some View {
        ZStack {
            // Draggable handles for each item
            ForEach($items) { $item in
                DraggableHandle(
                    item: $item,
                    mapWidth: mapWidth,
                    mapHeight: mapHeight,
                    editMode: editMode
                )
            }

            // Floating position panel (TOP of map so it doesn't block draggable items)
            if editMode {
                VStack {
                    positionPanel
                    Spacer()
                }
            }
        }
    }

    // MARK: - Position Panel (shows all coordinates)

    var positionPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.white)
                Text("Scene Editor")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("DRAG TO MOVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.yellow)
            }

            Divider().background(Color.white.opacity(0.3))

            ForEach(items) { item in
                HStack {
                    Text(item.label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .frame(width: 70, alignment: .leading)

                    Text("x: \(String(format: "%.2f", item.xPercent))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)

                    Text("y: \(String(format: "%.2f", item.yPercent))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                }
            }

            Divider().background(Color.white.opacity(0.3))

            // Code-ready output
            Text("// Copy these values:")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)

            ForEach(items) { item in
                Text(".position(x: w * \(String(format: "%.2f", item.xPercent)), y: h * \(String(format: "%.2f", item.yPercent)))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.yellow)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .padding(8)
    }
}

// MARK: - Draggable Handle

struct DraggableHandle: View {
    @Binding var item: SceneItem
    let mapWidth: CGFloat
    let mapHeight: CGFloat
    let editMode: Bool

    @State private var dragOffset: CGSize = .zero

    var currentX: CGFloat { item.xPercent * mapWidth + dragOffset.width }
    var currentY: CGFloat { item.yPercent * mapHeight + dragOffset.height }

    var body: some View {
        if editMode {
            // Edit mode: show draggable handle with coordinates
            VStack(spacing: 2) {
                // Position label
                Text("\(String(format: "%.0f", item.xPercent * 100))%, \(String(format: "%.0f", item.yPercent * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)

                // Draggable circle
                ZStack {
                    // Crosshair lines
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 1, height: 30)
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 30, height: 1)

                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 40, height: 40)

                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 40, height: 40)

                    Text(item.icon)
                        .font(.system(size: 16))
                }

                // Item name
                Text(item.label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.7))
                    .cornerRadius(4)
            }
            .position(x: currentX, y: currentY)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        // Update the percentage position
                        let newX = (item.xPercent * mapWidth + value.translation.width) / mapWidth
                        let newY = (item.yPercent * mapHeight + value.translation.height) / mapHeight

                        // Clamp to 0...1
                        item.xPercent = min(max(newX, 0.02), 0.98)
                        item.yPercent = min(max(newY, 0.02), 0.98)

                        // Reset drag offset
                        dragOffset = .zero

                        // Print to console for easy copying
                        print("📍 \(item.label): x: \(String(format: "%.2f", item.xPercent)), y: \(String(format: "%.2f", item.yPercent))")
                    }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)

        // Simulated map
        Image("bg_kitchen")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay(
                GeometryReader { geo in
                    SceneEditorOverlay(
                        mapWidth: geo.size.width,
                        mapHeight: geo.size.height,
                        items: .constant([
                            SceneItem(id: "counter", label: "Counter", icon: "🍽️", xPercent: 0.25, yPercent: 0.45),
                            SceneItem(id: "stove", label: "Stove", icon: "🔥", xPercent: 0.70, yPercent: 0.40),
                            SceneItem(id: "pantry", label: "Pantry", icon: "📦", xPercent: 0.50, yPercent: 0.70),
                            SceneItem(id: "pip", label: "Pip", icon: "🦔", xPercent: 0.50, yPercent: 0.30),
                        ]),
                        editMode: true
                    )
                }
            )
    }
}
