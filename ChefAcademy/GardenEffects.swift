//
//  GardenEffects.swift
//  ChefAcademy
//
//  Little one-shot effects for soil work in the Garden (Oct 22 2026): a dirt
//  puff when soil is loosened, planted or harvested, the harvested veggie
//  jumping out of its spot, and the coins it earned floating up.
//
//  Each effect animates in its own onAppear, so the caller shows a fresh copy
//  (with a new .id) every time it should play.
//

import SwiftUI

// MARK: - Dirt Puff

/// Eight sepia specks bursting out along the ground and fading.
struct DirtPuffView: View {
    @State private var spread = false

    private static let angles: [Double] = Array(stride(from: 0.0, to: 360.0, by: 45.0))

    var body: some View {
        ZStack {
            ForEach(Self.angles, id: \.self) { degrees in
                let a = degrees * .pi / 180
                Circle()
                    .fill(Color.AppTheme.sepia)
                    .frame(width: AppSpacing.xs, height: AppSpacing.xs)
                    // Flattened burst: the specks fly along the ground, not up
                    .offset(x: spread ? cos(a) * AnimationConstants.dirtPuffRadius : 0,
                            y: spread ? sin(a) * AnimationConstants.dirtPuffRadius / 2 : 0)
                    .opacity(spread ? 0 : 0.8)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(AnimationConstants.dirtPuff) { spread = true }
        }
    }
}

// MARK: - Veggie Pop

/// The harvested veggie jumping up out of its spot, spinning a little, fading.
struct VeggiePopView: View {
    let imageName: String
    let size: CGFloat

    @State private var popped = false

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .scaleEffect(popped ? AnimationConstants.harvestPopScale : 1)
            .rotationEffect(.degrees(popped ? AnimationConstants.harvestPopSpin : 0))
            .offset(y: popped ? -AnimationConstants.harvestPopRise : 0)
            .opacity(popped ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(AnimationConstants.harvestPop) { popped = true }
            }
    }
}

// MARK: - Coin Pop

/// "+N" coins floating up from a harvested spot.
struct GardenCoinPop: View {
    let amount: Int

    @State private var risen = false

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: "circle.fill")
                .foregroundColor(Color.AppTheme.goldenWheat)
            Text("+\(amount)")
                .foregroundColor(Color.AppTheme.darkBrown)
        }
        .font(.AppTheme.headline)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background(Color.AppTheme.warmCream.opacity(0.9))
        .cornerRadius(AppSpacing.pillCornerRadius)
        .offset(y: risen ? -AnimationConstants.coinPopRise : 0)
        .opacity(risen ? 0 : 1)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(AnimationConstants.harvestPop) { risen = true }
        }
        .accessibilityLabel("Earned \(amount) coins")
    }
}
