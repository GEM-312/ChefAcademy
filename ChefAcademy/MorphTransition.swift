//
//  MorphTransition.swift
//  ChefAcademy
//
//  Shared helpers for matchedGeometryEffect morph transitions.
//
//  TEACHING MOMENT: matchedGeometryEffect
//
//  This modifier lets two views with the SAME id in the SAME @Namespace
//  smoothly animate their position and size when you switch between them.
//  Think of it like handing a baton in a relay race — one view "becomes"
//  the other with a fluid morph animation.
//
//  Key rule: both views must be in the same view hierarchy (same ZStack).
//  It does NOT work across .fullScreenCover or .sheet (different windows).
//  That's why we use ZStack + conditional rendering instead.
//

import SwiftUI

// MARK: - Morph Source Modifier
//
// Apply this to the "small" version (e.g., recipe card in a list).
// When isActive is true, this view provides the geometry for the morph.

struct MorphSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: id,
                in: namespace,
                isSource: isActive
            )
    }
}

// MARK: - Morph Destination Modifier
//
// Apply this to the "big" version (e.g., full-screen detail view).
// When visible, this view takes over as the geometry source — SwiftUI
// morphs the frame from the old source position to this view's position.

struct MorphDestination: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: id,
                in: namespace,
                isSource: true
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Tag a view as the morph source (small card in list).
    /// `isActive` should be `true` when the detail is NOT showing.
    func morphSource(id: String, in namespace: Namespace.ID, isActive: Bool) -> some View {
        modifier(MorphSource(id: id, namespace: namespace, isActive: isActive))
    }

    /// Tag a view as the morph destination (expanded detail view).
    func morphDestination(id: String, in namespace: Namespace.ID) -> some View {
        modifier(MorphDestination(id: id, namespace: namespace))
    }
}

// MARK: - Drag-to-Dismiss Modifier
//
// Since we're replacing .fullScreenCover (which has built-in swipe-to-dismiss)
// with ZStack overlays, we need our own dismiss gesture.
// Drag down past the threshold → dismiss with morph animation.

struct DragToDismiss: ViewModifier {
    let onDismiss: () -> Void
    let threshold: CGFloat

    @State private var dragOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: max(0, dragOffset))
            .scaleEffect(dragOffset > 0 ? 1.0 - (dragOffset / 2000) : 1.0)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow downward drag
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > threshold {
                            Haptic.impact(.light)
                            withAnimation(AnimationConstants.morphTransition) {
                                onDismiss()
                            }
                        } else {
                            withAnimation(AnimationConstants.springQuick) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }
}

extension View {
    /// Add drag-down-to-dismiss behavior. Threshold defaults to 100pt.
    func dragToDismiss(threshold: CGFloat = 100, onDismiss: @escaping () -> Void) -> some View {
        modifier(DragToDismiss(onDismiss: onDismiss, threshold: threshold))
    }
}
