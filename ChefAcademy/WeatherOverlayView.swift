//
//  WeatherOverlayView.swift
//  ChefAcademy
//
//  Fun animated weather effects overlaid on the garden map!
//  Rain drops, snowflakes, sunshine glow, and more.
//  All touches pass through to the garden beneath.
//

import SwiftUI

// MARK: - Weather Overlay View

struct WeatherOverlayView: View {
    let weather: GardenWeather
    let mapWidth: CGFloat
    let mapHeight: CGFloat

    var body: some View {
        ZStack {
            switch weather {
            case .sunny:
                SunshineOverlay()
            case .partlyCloudy:
                PartlyCloudyOverlay()
            case .cloudy:
                CloudOverlay()
            case .rainy:
                RainOverlay(width: mapWidth, height: mapHeight)
            case .stormy:
                StormOverlay(width: mapWidth, height: mapHeight)
            case .snowy:
                SnowOverlay(width: mapWidth, height: mapHeight)
            case .windy:
                WindOverlay(width: mapWidth)
            }
        }
        .allowsHitTesting(false) // All touches pass through!
        .animation(AnimationConstants.weatherTransition, value: weather)
    }
}

// MARK: - Sunshine Overlay
/// Warm golden glow at the top of the garden

struct SunshineOverlay: View {
    @State private var pulse = false

    var body: some View {
        VStack {
            ZStack {
                // Golden radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.yellow.opacity(0.3),
                                Color.orange.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .opacity(pulse ? 0.6 : 0.4)

                // Sun icon
                Image(systemName: "sun.max.fill")
                    .font(.AppTheme.rounded(size: 40))
                    .foregroundColor(.yellow.opacity(0.5))
                    .rotationEffect(.degrees(pulse ? 15 : -15))
            }
            .offset(x: 60, y: -20)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Partly Cloudy Overlay

struct PartlyCloudyOverlay: View {
    @State private var cloudOffset: CGFloat = -50
    @State private var sunPulse = false

    var body: some View {
        VStack {
            ZStack {
                // Small sun peeking out
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(sunPulse ? 1.1 : 1.0)
                    .offset(x: 40, y: -10)

                // Drifting cloud
                Image(systemName: "cloud.fill")
                    .font(.AppTheme.rounded(size: 50))
                    .foregroundColor(.white.opacity(0.6))
                    .offset(x: cloudOffset, y: 10)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                cloudOffset = 50
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                sunPulse = true
            }
        }
    }
}

// MARK: - Cloud Overlay

struct CloudOverlay: View {
    @State private var cloud1X: CGFloat = -30
    @State private var cloud2X: CGFloat = 20

    var body: some View {
        VStack {
            ZStack {
                Image(systemName: "cloud.fill")
                    .font(.AppTheme.rounded(size: 60))
                    .foregroundColor(.gray.opacity(0.3))
                    .offset(x: cloud1X, y: 0)

                Image(systemName: "cloud.fill")
                    .font(.AppTheme.rounded(size: 40))
                    .foregroundColor(.gray.opacity(0.25))
                    .offset(x: cloud2X, y: 20)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                cloud1X = 30
            }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                cloud2X = -20
            }
        }
    }
}

// MARK: - Rain Overlay
//
// TEACHING MOMENT: Canvas vs ForEach for Particles
//
//   ForEach + SwiftUI Views (old approach):
//     - Each raindrop is a full SwiftUI View (RoundedRectangle)
//     - 15 views = 15 identity checks, 15 layout passes per frame
//     - SwiftUI diffs the view tree every frame even if nothing structural changed
//
//   Canvas (new approach):
//     - ONE view that draws ALL particles directly (like a painter on a canvas)
//     - No view diffing, no identity tracking, no layout engine overhead
//     - Just "draw rect at (x,y)" — as fast as Core Graphics
//
// For 15-20 simple shapes, Canvas is 3-5x more efficient. The difference
// grows with particle count. Games use this pattern ("immediate mode rendering")
// because creating objects per particle is wasteful when they're just dots.

struct RainOverlay: View {
    let width: CGFloat
    let height: CGFloat

    // Particle data — stored as simple structs, not SwiftUI views
    @State private var drops: [RainParticle] = []
    @State private var lastUpdate: Date = .now

    struct RainParticle {
        var x: CGFloat
        var y: CGFloat
        let speed: CGFloat  // points per second (not per tick!)
        let size: CGFloat
    }

    var body: some View {
        TimelineView(.animation) { context in
            // Calculate time delta since last frame — frame-rate independent!
            // TEACHING MOMENT: Using delta time means the rain falls at the
            // same speed whether the device renders at 30fps or 120fps.
            // Timer-based code ties speed to frame rate, which breaks on
            // ProMotion displays (120Hz) or when the system throttles.
            let now = context.date
            let dt = now.timeIntervalSince(lastUpdate)

            Canvas { ctx, size in
                // Cloud icon at top
                if let cloud = ctx.resolveSymbol(id: "cloud") {
                    ctx.draw(cloud, at: CGPoint(x: width * 0.4, y: 30))
                }

                // Draw all drops in one pass — no view diffing!
                for drop in drops {
                    let rect = CGRect(
                        x: drop.x - drop.size / 2,
                        y: drop.y - drop.size * 2,
                        width: drop.size,
                        height: drop.size * 4
                    )
                    ctx.fill(
                        RoundedRectangle(cornerRadius: 2).path(in: rect),
                        with: .color(.blue.opacity(0.4))
                    )
                }
            } symbols: {
                Image(systemName: "cloud.rain.fill")
                    .font(.AppTheme.rounded(size: 50))
                    .foregroundColor(.gray.opacity(0.4))
                    .tag("cloud")
            }
            .onChange(of: now) { _, newDate in
                updateParticles(dt: newDate.timeIntervalSince(lastUpdate))
                lastUpdate = newDate
            }
        }
        .onAppear { spawnDrops() }
    }

    private func spawnDrops() {
        drops = (0..<15).map { _ in
            RainParticle(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height),
                speed: CGFloat.random(in: 90...180), // points per second
                size: CGFloat.random(in: 2...3)
            )
        }
        lastUpdate = .now
    }

    private func updateParticles(dt: TimeInterval) {
        let delta = CGFloat(min(dt, 0.1)) // cap to prevent jumps after backgrounding
        var updated = drops
        for i in updated.indices {
            updated[i].y += updated[i].speed * delta
            if updated[i].y > height {
                updated[i].y = -10
                updated[i].x = CGFloat.random(in: 0...width)
            }
        }
        drops = updated
    }
}

// MARK: - Storm Overlay

struct StormOverlay: View {
    let width: CGFloat
    let height: CGFloat

    @State private var drops: [RainOverlay.RainParticle] = []
    @State private var lastUpdate: Date = .now
    @State private var flashOpacity: Double = 0
    @State private var lightningTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Lightning flash only (removed dark tint — it muddied the art)
            Color.white.opacity(flashOpacity)

            // Storm particles + cloud via Canvas
            TimelineView(.animation) { context in
                let now = context.date

                Canvas { ctx, size in
                    // Storm cloud
                    if let cloud = ctx.resolveSymbol(id: "stormCloud") {
                        ctx.draw(cloud, at: CGPoint(x: width * 0.5, y: 30))
                    }

                    // Heavy rain drops
                    for drop in drops {
                        let rect = CGRect(
                            x: drop.x - drop.size / 2,
                            y: drop.y - drop.size * 2.5,
                            width: drop.size,
                            height: drop.size * 5
                        )
                        ctx.fill(
                            RoundedRectangle(cornerRadius: 2).path(in: rect),
                            with: .color(.blue.opacity(0.5))
                        )
                    }
                } symbols: {
                    Image(systemName: "cloud.bolt.rain.fill")
                        .font(.AppTheme.rounded(size: 55))
                        .foregroundColor(.gray.opacity(0.5))
                        .tag("stormCloud")
                }
                .onChange(of: now) { _, newDate in
                    let dt = newDate.timeIntervalSince(lastUpdate)
                    updateStormParticles(dt: dt)
                    lastUpdate = newDate
                }
            }
        }
        .onAppear {
            spawnStorm()
            lightningTask?.cancel()
            lightningTask = Task { await runLightningLoop() }
        }
        .onDisappear {
            lightningTask?.cancel()
            lightningTask = nil
        }
    }

    private func spawnStorm() {
        drops = (0..<20).map { _ in
            RainOverlay.RainParticle(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height),
                speed: CGFloat.random(in: 150...240), // points per second
                size: CGFloat.random(in: 2...4)
            )
        }
        lastUpdate = .now
    }

    private func updateStormParticles(dt: TimeInterval) {
        let delta = CGFloat(min(dt, 0.1))
        var updated = drops
        for i in updated.indices {
            updated[i].y += updated[i].speed * delta
            if updated[i].y > height {
                updated[i].y = -10
                updated[i].x = CGFloat.random(in: 0...width)
            }
        }
        drops = updated
    }

    @MainActor
    private func runLightningLoop() async {
        while !Task.isCancelled {
            let delay = Double.random(in: 5...10)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.fadeQuick) { flashOpacity = 0.3 }
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.fadeFast) { flashOpacity = 0 }
        }
    }
}

// MARK: - Snow Overlay

struct SnowOverlay: View {
    let width: CGFloat
    let height: CGFloat

    @State private var flakes: [SnowParticle] = []
    @State private var lastUpdate: Date = .now

    struct SnowParticle {
        var x: CGFloat
        var y: CGFloat
        let speed: CGFloat    // points per second
        let drift: CGFloat    // horizontal sway amplitude
        let size: CGFloat
        var phase: CGFloat = 0
    }

    var body: some View {
        ZStack {
            Color.cyan.opacity(0.05)

            TimelineView(.animation) { context in
                let now = context.date

                Canvas { ctx, size in
                    // Snow cloud
                    if let cloud = ctx.resolveSymbol(id: "snowCloud") {
                        ctx.draw(cloud, at: CGPoint(x: width * 0.5, y: 25))
                    }

                    // Snowflakes — circles drawn directly
                    for flake in flakes {
                        let rect = CGRect(
                            x: flake.x - flake.size / 2,
                            y: flake.y - flake.size / 2,
                            width: flake.size,
                            height: flake.size
                        )
                        ctx.fill(
                            Circle().path(in: rect),
                            with: .color(.white.opacity(0.7))
                        )
                    }
                } symbols: {
                    Image(systemName: "cloud.snow.fill")
                        .font(.AppTheme.rounded(size: 50))
                        .foregroundColor(.gray.opacity(0.35))
                        .tag("snowCloud")
                }
                .onChange(of: now) { _, newDate in
                    let dt = newDate.timeIntervalSince(lastUpdate)
                    updateSnowParticles(dt: dt)
                    lastUpdate = newDate
                }
            }
        }
        .onAppear { spawnSnow() }
    }

    private func spawnSnow() {
        flakes = (0..<20).map { _ in
            SnowParticle(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height),
                speed: CGFloat.random(in: 15...45),  // points per second
                drift: CGFloat.random(in: 0.3...1.0),
                size: CGFloat.random(in: 3...6)
            )
        }
        lastUpdate = .now
    }

    private func updateSnowParticles(dt: TimeInterval) {
        let delta = CGFloat(min(dt, 0.1))
        var updated = flakes
        for i in updated.indices {
            updated[i].y += updated[i].speed * delta
            updated[i].phase += 1.5 * delta // smooth sway independent of frame rate
            updated[i].x += sin(updated[i].phase) * updated[i].drift
            if updated[i].y > height {
                updated[i].y = -10
                updated[i].x = CGFloat.random(in: 0...width)
            }
        }
        flakes = updated
    }
}

// MARK: - Wind Overlay

struct WindOverlay: View {
    let width: CGFloat

    @State private var line1X: CGFloat = -100
    @State private var line2X: CGFloat = -60
    @State private var line3X: CGFloat = -80

    var body: some View {
        ZStack {
            // Wind streaks (thin lines blowing across)
            WindStreak()
                .stroke(Color.AppTheme.sage.opacity(0.3), lineWidth: 1.5)
                .frame(width: 80, height: 8)
                .offset(x: line1X, y: 60)

            WindStreak()
                .stroke(Color.AppTheme.sage.opacity(0.25), lineWidth: 1)
                .frame(width: 60, height: 6)
                .offset(x: line2X, y: 120)

            WindStreak()
                .stroke(Color.AppTheme.sage.opacity(0.2), lineWidth: 1.5)
                .frame(width: 70, height: 7)
                .offset(x: line3X, y: 180)

            // Wind icon
            Image(systemName: "wind")
                .font(.AppTheme.rounded(size: 30))
                .foregroundColor(Color.AppTheme.sage.opacity(0.4))
                .position(x: width * 0.7, y: 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                line1X = width + 100
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false).delay(0.3)) {
                line2X = width + 80
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false).delay(0.7)) {
                line3X = width + 90
            }
        }
    }
}

/// A simple curved line shape for wind streaks
struct WindStreak: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: 0)
        )
        return path
    }
}

// MARK: - Weather Badge (for GardenView header)

struct WeatherBadge: View {
    @ObservedObject var weatherService: GardenWeatherService
    var isIPad: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: weatherService.currentWeather.systemIcon)
                .foregroundColor(weatherService.currentWeather.iconColor)
                .font(.system(size: isIPad ? 18 : 14))

            Text("\(weatherService.temperature)°")
                .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
        }
        .padding(.horizontal, isIPad ? AppSpacing.md : AppSpacing.sm)
        .padding(.vertical, isIPad ? AppSpacing.sm : AppSpacing.xs)
        .background(Color.AppTheme.warmCream.opacity(0.9))
        .cornerRadius(AppSpacing.largeCornerRadius)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ForEach(GardenWeather.allCases, id: \.self) { weather in
            HStack {
                Image(systemName: weather.systemIcon)
                    .foregroundColor(weather.iconColor)
                Text(weather.displayName)
                Spacer()
                Text("x\(String(format: "%.2f", weather.growthMultiplier))")
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Seasonal Gradient Overlay

/// Subtle gradient tint that shifts the garden's mood by season.
/// Spring = soft green/pink, Summer = warm gold, Fall = amber/brown, Winter = icy blue.
/// Overlaid on the garden background with low opacity for a natural look.
struct SeasonalOverlayView: View {
    let season: GardenSeason
    let mapWidth: CGFloat
    let mapHeight: CGFloat

    @State private var particleOffset: CGFloat = 0
    @State private var particleOpacity: Double = 1.0

    // Stable particle data — generated once per appearance so positions don't
    // jump on every parent re-render. Bug fix from May 10 weekly review.
    @State private var springPetals: [SpringPetal] = []
    @State private var summerDust: [SummerDust] = []
    @State private var fallLeaves: [FallLeaf] = []
    @State private var winterSparkles: [WinterSparkle] = []

    var body: some View {
        ZStack {
            // Gradient tint
            LinearGradient(
                colors: season.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: mapWidth, height: mapHeight)
            .allowsHitTesting(false)

            // Seasonal particles
            switch season {
            case .spring:
                springParticles
            case .summer:
                summerParticles
            case .fall:
                fallParticles
            case .winter:
                winterParticles
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            startParticleAnimation()
            seedParticleData()
        }
    }

    // MARK: - Spring Particles (floating petals)

    var springParticles: some View {
        // Procedural petal shapes — cheaper than emoji font rendering.
        // Positions seeded once via @State; only `particleOffset` drives motion.
        ForEach(springPetals) { petal in
            Ellipse()
                .fill(Color.pink.opacity(0.35))
                .frame(width: petal.width, height: petal.height)
                .offset(
                    x: petal.xOffset,
                    y: particleOffset + petal.baseY
                )
                .rotationEffect(.degrees(petal.rotationBase + Double(particleOffset) * 0.3))
        }
    }

    // MARK: - Summer Particles (heat shimmer / floating dust)

    var summerParticles: some View {
        ForEach(summerDust) { dust in
            Circle()
                .fill(Color.AppTheme.goldenWheat.opacity(0.15))
                .frame(width: dust.diameter)
                .blur(radius: 20)
                .offset(
                    x: dust.xOffset,
                    y: dust.yOffset + particleOffset * 0.2
                )
                .opacity(particleOpacity * 0.6)
        }
    }

    // MARK: - Fall Particles (falling leaves)

    private static let fallLeafColors: [Color] = [
        Color.AppTheme.terracotta,
        Color.AppTheme.autumnBrown,
        Color.AppTheme.goldenWheat
    ]

    var fallParticles: some View {
        // Procedural leaf shapes — 3 autumn colors, cheaper than emoji.
        ForEach(fallLeaves) { leaf in
            Ellipse()
                .fill(Self.fallLeafColors[leaf.colorIndex].opacity(0.5))
                .frame(width: leaf.width, height: leaf.height)
                .offset(
                    x: sin(leaf.phase + particleOffset * 0.02) * mapWidth * 0.3,
                    y: particleOffset * 0.5 + leaf.baseY - mapHeight * 0.3
                )
                .rotationEffect(.degrees(Double(particleOffset) * 0.5 + leaf.rotationBase))
        }
    }

    // MARK: - Winter Particles (gentle frost sparkles)

    var winterParticles: some View {
        ForEach(winterSparkles) { sparkle in
            Image(systemName: "sparkle")
                .font(.AppTheme.rounded(size: sparkle.fontSize))
                .foregroundColor(Color.AppTheme.frostBlue.opacity(0.5))
                .offset(x: sparkle.xOffset, y: sparkle.yOffset)
                .opacity(particleOpacity * 0.7)
                .scaleEffect(particleOpacity > 0.5 ? 1.0 : 0.6)
        }
    }

    // MARK: - Stable Particle Seeding

    private func seedParticleData() {
        if springPetals.isEmpty { springPetals = makeSpringPetals() }
        if summerDust.isEmpty   { summerDust   = makeSummerDust() }
        if fallLeaves.isEmpty   { fallLeaves   = makeFallLeaves() }
        if winterSparkles.isEmpty { winterSparkles = makeWinterSparkles() }
    }

    // Each builder is a separate function so the type-checker doesn't choke
    // on inline `.map` closures with arithmetic + struct init.
    private func makeSpringPetals() -> [SpringPetal] {
        (0..<8).map { i in
            let widthVariant: CGFloat = CGFloat(10 + (i % 3) * 3)
            let heightVariant: CGFloat = CGFloat(6 + (i % 3) * 2)
            return SpringPetal(
                xOffset: CGFloat.random(in: -mapWidth/2...mapWidth/2),
                baseY: CGFloat(i * 60),
                width: widthVariant,
                height: heightVariant,
                rotationBase: Double(i) * 15
            )
        }
    }

    private func makeSummerDust() -> [SummerDust] {
        (0..<5).map { _ in
            SummerDust(
                xOffset: CGFloat.random(in: -mapWidth/3...mapWidth/3),
                yOffset: CGFloat.random(in: -mapHeight/4...mapHeight/4),
                diameter: CGFloat.random(in: 40...80)
            )
        }
    }

    private func makeFallLeaves() -> [FallLeaf] {
        (0..<8).map { i in
            let widthVariant: CGFloat = CGFloat(12 + (i % 3) * 4)
            let heightVariant: CGFloat = CGFloat(8 + (i % 3) * 2)
            return FallLeaf(
                phase: CGFloat(i) * 0.8,
                baseY: CGFloat(i * 50),
                width: widthVariant,
                height: heightVariant,
                rotationBase: Double(i) * 30,
                colorIndex: i % 3
            )
        }
    }

    private func makeWinterSparkles() -> [WinterSparkle] {
        (0..<6).map { _ in
            WinterSparkle(
                xOffset: CGFloat.random(in: -mapWidth/2.5...mapWidth/2.5),
                yOffset: CGFloat.random(in: -mapHeight/3...mapHeight/3),
                fontSize: CGFloat.random(in: 8...14)
            )
        }
    }

    // MARK: - Animation

    private func startParticleAnimation() {
        // Slow continuous drift
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            particleOffset = mapHeight
        }
        // Gentle fade pulse
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            particleOpacity = 0.4
        }
    }
}

// MARK: - Stable Seasonal Particle Data

private struct SpringPetal: Identifiable {
    let id = UUID()
    let xOffset: CGFloat
    let baseY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotationBase: Double
}

private struct SummerDust: Identifiable {
    let id = UUID()
    let xOffset: CGFloat
    let yOffset: CGFloat
    let diameter: CGFloat
}

private struct FallLeaf: Identifiable {
    let id = UUID()
    let phase: CGFloat
    let baseY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotationBase: Double
    let colorIndex: Int
}

private struct WinterSparkle: Identifiable {
    let id = UUID()
    let xOffset: CGFloat
    let yOffset: CGFloat
    let fontSize: CGFloat
}
