//
//  FamilySetupView.swift
//  ChefAcademy
//
//  First-launch wizard: creates parent + first child profiles.
//

import SwiftUI
import SwiftData
import Combine
import AVFoundation

// MARK: - Family Setup Manager

class FamilySetupManager: ObservableObject {
    @Published var step: SetupStep = .welcome

    // Parent data
    @Published var parentName: String = ""
    @Published var parentGender: Gender = .girl
    @Published var parentOutfit: Outfit = .chefWhite
    @Published var parentHeadCovering: HeadCovering = .chefHatWhite
    @Published var parentPIN: String = ""

    // Child data
    @Published var childName: String = ""
    @Published var childGender: Gender = .girl
    @Published var childOutfit: Outfit = .apronRed
    @Published var childHeadCovering: HeadCovering = .chefHatWhite
    @Published var childAllergens: [FoodAllergen] = []

    enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case parentName = 1
        case parentAvatar = 2
        case setPIN = 3
        case childName = 4
        case childAvatar = 5
        case childAllergens = 6
        case choosePipVoice = 7
        case meetPip = 8
        case ready = 9
    }

    func nextStep() {
        let all = SetupStep.allCases
        if let idx = all.firstIndex(of: step), idx < all.count - 1 {
            withAnimation(AnimationConstants.fadeMedium) {
                step = all[idx + 1]
            }
        }
    }

    func previousStep() {
        let all = SetupStep.allCases
        if let idx = all.firstIndex(of: step), idx > 0 {
            withAnimation(AnimationConstants.fadeMedium) {
                step = all[idx - 1]
            }
        }
    }
}

// MARK: - Family Setup View

struct FamilySetupView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var avatarModel: AvatarModel
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var setupManager = FamilySetupManager()

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            switch setupManager.step {
            case .welcome:
                FamilyWelcomeStep(setupManager: setupManager)

            case .parentName:
                FamilyNameStep(
                    title: "What's your name?",
                    subtitle: "The grown-up's name",
                    name: $setupManager.parentName,
                    onNext: { setupManager.nextStep() },
                    onBack: { setupManager.previousStep() }
                )
                .onAppear {
                    // Pre-fill with the name from Sign in with Apple (if available)
                    if setupManager.parentName.isEmpty, let appleName = authManager.signedInName {
                        setupManager.parentName = appleName
                    }
                }

            case .parentAvatar:
                FamilyAvatarStep(
                    title: "Create your chef!",
                    gender: $setupManager.parentGender,
                    outfit: $setupManager.parentOutfit,
                    headCovering: $setupManager.parentHeadCovering,
                    onNext: { setupManager.nextStep() },
                    onBack: { setupManager.previousStep() },
                )

            case .setPIN:
                FamilyPINSetupStep(
                    setupManager: setupManager,
                    onComplete: { pin in
                        setupManager.parentPIN = pin
                        setupManager.nextStep()
                    },
                    onBack: { setupManager.previousStep() }
                )

            case .childName:
                FamilyNameStep(
                    title: "Now your little chef!",
                    subtitle: "What's the kid's name?",
                    name: $setupManager.childName,
                    onNext: { setupManager.nextStep() },
                    onBack: { setupManager.previousStep() }
                )

            case .childAvatar:
                FamilyAvatarStep(
                    title: "Create your little chef!",
                    gender: $setupManager.childGender,
                    outfit: $setupManager.childOutfit,
                    headCovering: $setupManager.childHeadCovering,
                    onNext: { setupManager.nextStep() },
                    onBack: { setupManager.previousStep() },
                )

            case .childAllergens:
                AllergenPickerStep(
                    title: "Any food allergies?",
                    subtitle: "Select any allergens for \(setupManager.childName)",
                    selectedAllergens: $setupManager.childAllergens,
                    onNext: { setupManager.nextStep() },
                    onBack: { setupManager.previousStep() }
                )

            case .choosePipVoice:
                // TEACHING MOMENT: Voice picker goes BEFORE Meet Pip so
                // when Pip introduces himself, he already uses the chosen voice.
                // This makes the "Meet Pip" moment feel personal and magical!
                FamilyVoiceStep(
                    onNext: { setupManager.nextStep() },
                    onBack: { setupManager.previousStep() }
                )

            case .meetPip:
                FamilyMeetPipStep(
                    childName: setupManager.childName,
                    onNext: { setupManager.nextStep() }
                )

            case .ready:
                FamilyReadyStep(
                    childName: setupManager.childName,
                    childGender: setupManager.childGender,
                    onStart: { finishSetup() }
                )
            }
        }
    }

    private func finishSetup() {
        guard let context = sessionManager.modelContext else { return }

        // Create family — PIN goes to Keychain, not SwiftData (security)
        // Link to the parent's Apple ID so this family syncs across their devices
        let family = FamilyProfile(parentPIN: "", appleUserID: authManager.appleUserID ?? "")
        PINKeychain.save(pin: setupManager.parentPIN)

        // Create parent profile
        let parentProfile = UserProfile(
            name: setupManager.parentName,
            role: .parent,
            gender: setupManager.parentGender,
            headCovering: setupManager.parentHeadCovering,
            outfit: setupManager.parentOutfit
        )
        // Create child profile
        let childProfile = UserProfile(
            name: setupManager.childName,
            role: .child,
            gender: setupManager.childGender,
            headCovering: setupManager.childHeadCovering,
            outfit: setupManager.childOutfit
        )

        // Store child allergens
        childProfile.setAllergens(setupManager.childAllergens)

        context.insert(family)
        context.insert(parentProfile)
        context.insert(childProfile)
        family.addMember(parentProfile)
        family.addMember(childProfile)
        // Don't pre-create PlayerData — selectProfile() will create it
        // with starter seeds, coins, and garden plots via resetToDefaults()
        try? context.save()

        sessionManager.familyProfile = family

        // Auto-select the child profile and start playing
        sessionManager.selectProfile(childProfile, gameState: gameState, avatarModel: avatarModel)
    }
}

// MARK: - Setup Steps

struct FamilyWelcomeStep: View {
    @ObservedObject var setupManager: FamilySetupManager
    @State private var showContent = false

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            PipHeaderStack(
                title: "Welcome to",
                pose: .gotIdea,
                size: .hero,
                strokeBorder: true
            )
            .scaleEffect(showContent ? 1 : 0.5)
            .opacity(showContent ? 1 : 0)

            VStack(spacing: AppSpacing.sm) {
                Text("Pip's Kitchen Garden")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)

            Text("Let's set up your family!")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
                .italic()
                .opacity(showContent ? 1 : 0)

            Spacer()

            Button(action: { setupManager.nextStep() }) {
                HStack {
                    Text("Let's Begin!")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppSpacing.xl)
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: AppSpacing.xxl)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }
}

struct FamilyNameStep: View {
    let title: String
    let subtitle: String
    @Binding var name: String
    let onNext: () -> Void
    let onBack: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)
                Text(subtitle)
                    .font(.AppTheme.subheadline)
                    .foregroundColor(Color.AppTheme.sepia)
            }

            TextField("Enter name", text: $name)
                .font(.AppTheme.title3)
                .foregroundColor(Color.AppTheme.darkBrown)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.cardCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.xl)
                .focused($isFocused)

            Spacer()

            HStack(spacing: AppSpacing.md) {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                Button(action: {
                    isFocused = false
                    onNext()
                }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
            }
            .padding(AppSpacing.md)
        }
        .onTapGesture { isFocused = false }
    }
}

struct FamilyAvatarStep: View {
    let title: String
    @Binding var gender: Gender
    @Binding var outfit: Outfit
    @Binding var headCovering: HeadCovering
    let onNext: () -> Void
    let onBack: () -> Void

    // MARK: - State

    @State private var genderChosen = false

    // Animation state
    @State private var activeAnimation: AvatarAnimation? = nil
    @State private var animFrameIndex: Int = 0
    @State private var animTimer: Timer? = nil

    // Color reveal phases
    @State private var outfitAnimFinished = false   // outfit anim done → show color picker
    @State private var hatAnimFinished = false       // hat anim done → show hat color picker
    @State private var showColoredOutfit = false     // colored outfit frame visible
    @State private var showColoredHat = false        // colored hat frame visible

    // Ripple shader state
    @State private var rippleTime: CGFloat = 0
    @State private var rippleOrigin: CGPoint = CGPoint(x: 200, y: 200)
    @State private var rippleTimer: Timer? = nil

    /// Frame animation for the outfit
    private var outfitAnimation: AvatarAnimation {
        gender == .boy ? .boyCoat : .girlApron
    }

    /// Frame animation for the hat
    private var hatAnimation: AvatarAnimation {
        gender == .boy ? .boyWearHat : .girlWearHat
    }

    /// Grayscale last frame name (held after animation finishes)
    private var grayscaleLastFrame: String {
        outfitAnimation.frameNames.last ?? (gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
    }

    /// Grayscale last frame for the hat animation
    private var hatGrayscaleLastFrame: String {
        hatAnimation.frameNames.last ?? grayscaleLastFrame
    }

    /// The current frame to display during animation, or the grayscale last frame
    private var currentDisplayFrame: String {
        if let anim = activeAnimation {
            let idx = min(animFrameIndex, anim.frameNames.count - 1)
            return anim.frameNames[idx]
        }
        // After hat anim finished, show hat last frame
        if hatAnimFinished {
            return hatGrayscaleLastFrame
        }
        // After outfit anim finished, show outfit last frame
        if outfitAnimFinished {
            return grayscaleLastFrame
        }
        // Default: static gender card
        return gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"
    }

    var body: some View {
        GeometryReader { outerGeo in
            let landscape = outerGeo.size.width > outerGeo.size.height

            VStack(spacing: 0) {
                Text(title)
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .padding(.top, landscape ? AppSpacing.sm : AppSpacing.lg)

                // MARK: - Avatar Display Area
                GeometryReader { geo in
                    let screenW = geo.size.width
                    let screenH = geo.size.height
                    let bigSize: CGFloat = landscape
                        ? min(outerGeo.size.height * 0.35, 280)
                        : screenW * 0.55
                    let smallSize: CGFloat = min(screenW * 0.3, screenH * 0.8, 300)

                    if !genderChosen {
                        // Phase 1: Show BOTH avatars side by side
                        HStack(spacing: AppSpacing.lg) {
                            Spacer()
                            ForEach(Gender.allCases) { g in
                                Button(action: {
                                    withAnimation(AnimationConstants.springMedium) {
                                        gender = g
                                        genderChosen = true
                                        outfit = .none
                                        headCovering = .none
                                        resetAllState()
                                    }
                                    // Auto-play outfit animation after gender pick
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .seconds(0.4))
                                        guard !Task.isCancelled else { return }
                                        playOutfitAnimation()
                                    }
                                }) {
                                    VStack(spacing: 6) {
                                        let img = g == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"
                                        Image(img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: smallSize, height: smallSize)
                                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.largeCornerRadius))

                                        Text(g.rawValue)
                                            .font(.AppTheme.body)
                                            .foregroundColor(Color.AppTheme.darkBrown)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Phases 2-5: Chosen avatar with color reveal
                        VStack(spacing: 6) {
                            ZStack {
                                // Base: grayscale frame (animation or held last frame)
                                Image(currentDisplayFrame)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)

                                // Colored outfit frame — appears with ripple when color picked
                                if showColoredOutfit, let coloredName = outfit.coloredFrameName(for: gender) {
                                    Image(coloredName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .layerEffect(
                                            ShaderLibrary.Ripple(
                                                .float2(rippleOrigin.x, rippleOrigin.y),
                                                .float(rippleTime),
                                                .float(12),     // amplitude
                                                .float(15),     // frequency
                                                .float(8),      // decay
                                                .float(1400)    // speed
                                            ),
                                            maxSampleOffset: CGSize(width: 12, height: 12)
                                        )
                                        .transition(.identity)
                                }

                                // Colored hat frame — appears with ripple when hat color picked
                                if showColoredHat, let hatName = headCovering.coloredHatFrameName(for: gender) {
                                    Image(hatName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .layerEffect(
                                            ShaderLibrary.Ripple(
                                                .float2(rippleOrigin.x, rippleOrigin.y),
                                                .float(rippleTime),
                                                .float(12),
                                                .float(15),
                                                .float(8),
                                                .float(1400)
                                            ),
                                            maxSampleOffset: CGSize(width: 12, height: 12)
                                        )
                                        .transition(.identity)
                                }
                            }
                            .frame(width: bigSize, height: bigSize)
                            .clipShape(RoundedRectangle(cornerRadius: 24))

                            HStack(spacing: AppSpacing.sm) {
                                Text(gender.rawValue)
                                    .font(.AppTheme.body)
                                    .foregroundColor(Color.AppTheme.darkBrown)

                                Button(action: {
                                    withAnimation(AnimationConstants.springMedium) {
                                        genderChosen = false
                                        outfit = .none
                                        headCovering = .none
                                        resetAllState()
                                    }
                                }) {
                                    Text("Change")
                                        .font(.AppTheme.caption)
                                        .foregroundColor(Color.AppTheme.sage)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: genderChosen
                    ? (landscape ? outerGeo.size.height * 0.4 : outerGeo.size.height * 0.45)
                    : (landscape ? outerGeo.size.height * 0.55 : outerGeo.size.height * 0.45))
                .padding(.vertical, AppSpacing.xs)

                // MARK: - Color Pickers (appear after animations finish)
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Outfit color picker — appears after outfit animation finishes
                        if outfitAnimFinished {
                            OutfitColorPicker(
                                selectedOutfit: $outfit,
                                gender: gender,
                                onColorPicked: { origin in
                                    headCovering = .none
                                    showColoredHat = false
                                    triggerRipple(from: origin)
                                    showColoredOutfit = true
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // Hat color picker — appears after outfit color is chosen
                        if outfit.isChosen {
                            HatColorPicker(
                                selectedCovering: $headCovering,
                                onColorPicked: { origin in
                                    // Play hat animation, then reveal colored hat
                                    showColoredHat = false
                                    hatAnimFinished = false
                                    playHatAnimation(rippleOrigin: origin)
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(AppSpacing.md)
                    .animation(AnimationConstants.springMedium, value: outfitAnimFinished)
                    .animation(AnimationConstants.springMedium, value: outfit.isChosen)
                }
                .cornerRadius(AppSpacing.cardCornerRadius, corners: [.topLeft, .topRight])

                // MARK: - Navigation
                HStack(spacing: AppSpacing.md) {
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: onNext) {
                        HStack {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppSpacing.md)
                .background(Color.AppTheme.cream)
            }
        }
        .onDisappear {
            stopAnim()
            stopRipple()
        }
    }

    // MARK: - Animation

    private func playOutfitAnimation() {
        stopAnim()
        let anim = outfitAnimation
        activeAnimation = anim
        animFrameIndex = 0
        outfitAnimFinished = false
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / anim.fps, repeats: true) { _ in
            Task { @MainActor in
                let next = animFrameIndex + 1
                if next >= anim.frameNames.count {
                    // Animation done — hold last frame, show color picker
                    animTimer?.invalidate()
                    animTimer = nil
                    activeAnimation = nil
                    withAnimation(AnimationConstants.springMedium) {
                        outfitAnimFinished = true
                    }
                } else {
                    animFrameIndex = next
                }
            }
        }
    }

    private func playHatAnimation(rippleOrigin origin: CGPoint) {
        stopAnim()
        let anim = hatAnimation
        activeAnimation = anim
        animFrameIndex = 0
        hatAnimFinished = false
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / anim.fps, repeats: true) { _ in
            Task { @MainActor in
                let next = animFrameIndex + 1
                if next >= anim.frameNames.count {
                    // Hat animation done — reveal colored hat with ripple
                    animTimer?.invalidate()
                    animTimer = nil
                    activeAnimation = nil
                    hatAnimFinished = true
                    triggerRipple(from: origin)
                    showColoredHat = true
                } else {
                    animFrameIndex = next
                }
            }
        }
    }

    private func stopAnim() {
        animTimer?.invalidate()
        animTimer = nil
        activeAnimation = nil
        animFrameIndex = 0
    }

    // MARK: - Ripple Effect

    private func triggerRipple(from origin: CGPoint) {
        stopRipple()
        rippleOrigin = origin
        rippleTime = 0
        Haptic.impact(.medium)

        // Animate rippleTime from 0 to ~2 seconds over 60 steps
        rippleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { timer in
            Task { @MainActor in
                rippleTime += 1.0 / 30.0
                if rippleTime > 2.0 {
                    timer.invalidate()
                    rippleTimer = nil
                }
            }
        }
    }

    private func stopRipple() {
        rippleTimer?.invalidate()
        rippleTimer = nil
        rippleTime = 0
    }

    // MARK: - Reset

    private func resetAllState() {
        stopAnim()
        stopRipple()
        outfitAnimFinished = false
        hatAnimFinished = false
        showColoredOutfit = false
        showColoredHat = false
    }
}

// MARK: - Outfit Color Picker
//
// TEACHING MOMENT: This replaces the old OutfitSelector for the onboarding flow.
// Instead of showing outfit names + icons, we show ONLY color circles.
// The kid already sees the outfit shape from the animation — they just pick the color.
// The GeometryReader on each circle captures the tap position for the ripple origin.

struct OutfitColorPicker: View {
    @Binding var selectedOutfit: Outfit
    let gender: Gender
    let onColorPicked: (CGPoint) -> Void

    private var colorOptions: [Outfit] {
        Outfit.options(for: gender).filter { $0.isChosen }
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Pick a color!")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            HStack(spacing: AppSpacing.md) {
                ForEach(colorOptions) { option in
                    GeometryReader { geo in
                        Button(action: {
                            selectedOutfit = option
                            Haptic.selection()
                            // Pass the center of this circle as ripple origin
                            let frame = geo.frame(in: .global)
                            onColorPicked(CGPoint(x: frame.midX, y: frame.midY))
                        }) {
                            Circle()
                                .fill(option.color)
                                .overlay(
                                    Circle()
                                        .stroke(Color.AppTheme.darkBrown, lineWidth: selectedOutfit == option ? 3 : 0)
                                )
                                .scaleEffect(selectedOutfit == option ? 1.15 : 1.0)
                                .animation(AnimationConstants.springQuick, value: selectedOutfit)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 50, height: 50)
                }
            }
        }
    }
}

// MARK: - Hat Color Picker

struct HatColorPicker: View {
    @Binding var selectedCovering: HeadCovering
    let onColorPicked: (CGPoint) -> Void

    private var colorOptions: [HeadCovering] {
        HeadCovering.allCases.filter { $0 != .none }
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Chef hat color!")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            HStack(spacing: AppSpacing.md) {
                // "No hat" option
                GeometryReader { geo in
                    Button(action: {
                        selectedCovering = .none
                        Haptic.selection()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.AppTheme.parchment)
                            Image(systemName: "xmark")
                                .font(.AppTheme.rounded(size: 16, weight: .medium))
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        .overlay(
                            Circle()
                                .stroke(Color.AppTheme.darkBrown, lineWidth: selectedCovering == .none ? 3 : 0)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 44, height: 44)

                ForEach(colorOptions) { option in
                    GeometryReader { geo in
                        Button(action: {
                            selectedCovering = option
                            Haptic.selection()
                            let frame = geo.frame(in: .global)
                            onColorPicked(CGPoint(x: frame.midX, y: frame.midY))
                        }) {
                            Circle()
                                .fill(option.color)
                                .overlay(
                                    Circle()
                                        .stroke(Color.AppTheme.darkBrown, lineWidth: selectedCovering == option ? 3 : 0)
                                )
                                .scaleEffect(selectedCovering == option ? 1.15 : 1.0)
                                .animation(AnimationConstants.springQuick, value: selectedCovering)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 44, height: 44)
                }
            }
        }
    }
}

struct FamilyPINSetupStep: View {
    @ObservedObject var setupManager: FamilySetupManager
    let onComplete: (String) -> Void
    let onBack: () -> Void

    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var isConfirming: Bool = false
    @State private var shake: Bool = false
    @State private var showError: Bool = false

    private var currentPIN: String { isConfirming ? confirmPin : pin }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            PipHeaderStack(
                title: isConfirming ? "Confirm Your PIN" : "Set a Parent PIN",
                subtitle: isConfirming ? "Enter the same 4 digits" : "Only grown-ups need to know this!",
                pose: .thinking
            )

            // PIN dots
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < currentPIN.count ? Color.AppTheme.goldenWheat : Color.AppTheme.parchment)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 1))
                }
            }
            .offset(x: shake ? -10 : 0)

            if showError {
                Text("PINs don't match. Try again.")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.terracotta)
            }

            Spacer()

            // Number pad — Back / 0 / delete
            PINPadGrid(
                onDigit: appendDigit,
                leading: {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: AppSpacing.pinButtonWidth, height: AppSpacing.pinButtonHeight)
                    }
                },
                trailing: {
                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left.fill")
                            .font(.AppTheme.title2)
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: AppSpacing.pinButtonWidth, height: AppSpacing.pinButtonHeight)
                    }
                }
            )
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private func appendDigit(_ d: String) {
        showError = false
        if isConfirming {
            guard confirmPin.count < 4 else { return }
            confirmPin += d
            if confirmPin.count == 4 {
                if confirmPin == pin {
                    onComplete(pin)
                } else {
                    withAnimation(AnimationConstants.pinShake) { shake = true }
                    showError = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4))
                        guard !Task.isCancelled else { return }
                        shake = false
                        confirmPin = ""
                        pin = ""
                        isConfirming = false
                    }
                }
            }
        } else {
            guard pin.count < 4 else { return }
            pin += d
            if pin.count == 4 {
                isConfirming = true
            }
        }
    }

    private func deleteDigit() {
        if isConfirming {
            if !confirmPin.isEmpty { confirmPin.removeLast() }
        } else {
            if !pin.isEmpty { pin.removeLast() }
        }
        showError = false
    }
}

struct FamilyMeetPipStep: View {
    let childName: String
    let onNext: () -> Void
    @State private var showPip = false
    @State private var showDialogue = false
    @State private var dialogueIndex = 0

    // 3-dialog flow per UX audit (was 6). CTA "Let's grow!" surfaces on
    // dialog index 2 — the kid reaches the action in 3 taps, not 6.
    private var dialogues: [String] {
        [
            "Hi \(childName)! 🦔 I'm Pip, your kitchen garden buddy!",
            "Grow veggies → cook recipes → Feed Your Body!",
            "Tap seeds to start growing. Ready?"
        ]
    }

    var body: some View {
        ZStack {
            CottageBackground()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                PipWavingAnimatedView(size: .hero)
                    .scaleEffect(showPip ? 1 : 0.3)
                    .opacity(showPip ? 1 : 0)

                VStack(spacing: AppSpacing.md) {
                    Text("Pip")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.largeCornerRadius)

                    Text(dialogues[dialogueIndex])
                        .font(.AppTheme.title3)
                        .foregroundColor(Color.AppTheme.darkBrown)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 80)
                        .padding(AppSpacing.lg)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                        .opacity(showDialogue ? 1 : 0)
                }
                .padding(.horizontal, AppSpacing.lg)

                if dialogueIndex < dialogues.count - 1 {
                    Text("Tap to continue...")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.lightSepia)
                        .opacity(showDialogue ? 0.7 : 0)
                }

                Spacer()

                if dialogueIndex == dialogues.count - 1 {
                    Button(action: onNext) {
                        HStack {
                            Text("Let's grow!")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppSpacing.xl)
                }

                Spacer().frame(height: AppSpacing.xl)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard dialogueIndex < dialogues.count - 1 else { return }
            withAnimation(AnimationConstants.fadeFlyOut) { showDialogue = false }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.2))
                guard !Task.isCancelled else { return }
                dialogueIndex += 1
                withAnimation(AnimationConstants.fadeFast) { showDialogue = true }
            }
        }
        .onAppear {
            withAnimation(AnimationConstants.springFly) { showPip = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                withAnimation(AnimationConstants.fadeMedium) { showDialogue = true }
            }
        }
    }
}

struct FamilyReadyStep: View {
    let childName: String
    let childGender: Gender
    let onStart: () -> Void
    @State private var showContent = false

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Text("You're All Set!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)
                .opacity(showContent ? 1 : 0)

            Text("Welcome, Chef \(childName)!")
                .font(.AppTheme.title)
                .foregroundColor(Color.AppTheme.goldenWheat)
                .opacity(showContent ? 1 : 0)

            PipWavingAnimatedView(size: .custom(140))
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                FeatureRow(icon: "leaf.fill", text: "Grow vegetables in Pip's garden", systemIcon: true)
                FeatureRow(icon: "fork.knife", text: "Cook yummy healthy recipes", systemIcon: true)
                FeatureRow(icon: "figure.child", text: "Feed Your Body", systemIcon: true)
                FeatureRow(icon: "star.fill", text: "Earn badges and rewards", systemIcon: true)
            }
            .padding(AppSpacing.lg)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .padding(.horizontal, AppSpacing.lg)
            .opacity(showContent ? 1 : 0)

            Spacer()

            Button(action: onStart) {
                HStack {
                    Text("Let's Go!")
                    Image(systemName: "arrow.right.circle.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppSpacing.xl)
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: AppSpacing.xxl)
        }
        .background(Color.AppTheme.cream)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { showContent = true }
        }
    }
}

// MARK: - Voice Picker Step (Onboarding)
//
// TEACHING MOMENT: This step goes BEFORE "Meet Pip" in onboarding.
// The kid picks how Pip sounds, then immediately hears that voice
// when Pip introduces himself. This creates a personal connection —
// "I chose how my friend sounds!" — which increases engagement.
//

struct FamilyVoiceStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @ObservedObject private var pipVoice = PipVoice.shared
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sage)
                }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // Pip + title
                    PipHeaderStack(
                        title: "How should I talk?",
                        subtitle: "Read silently, or tap Preview to hear my voice",
                        pose: .pointsUpLeft,
                        clipToCircle: false
                    )
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                    .padding(.top, AppSpacing.md)

                    // Two options: Read Text (free) or Pip's Voice (subscription)
                    VStack(spacing: AppSpacing.md) {
                        VoiceOptionCard(
                            icon: "text.bubble.fill",
                            title: "Read Text",
                            subtitle: "Read Pip's words on screen — no voice",
                            color: Color.AppTheme.sage,
                            isSelected: pipVoice.voiceMode == .readText
                        ) {
                            pipVoice.voiceMode = .readText
                            pipVoice.stop()
                        }

                        VoiceOptionCard(
                            icon: "waveform.circle.fill",
                            title: "Pip's Voice",
                            subtitle: pipVoice.hasSubscription
                                ? "Pip talks with a real character voice!"
                                : "Custom character voice — Pip Plus $3.99/mo",
                            color: Color.AppTheme.goldenWheat,
                            isSelected: pipVoice.voiceMode == .elevenLabs,
                            isLocked: !pipVoice.hasSubscription
                        ) {
                            if pipVoice.hasSubscription {
                                pipVoice.voiceMode = .elevenLabs
                            }
                        }

                        // Preview button
                        Button(action: {
                            pipVoice.previewElevenLabsVoice()
                        }) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: pipVoice.isSpeaking ? "speaker.wave.3.fill" : "play.circle.fill")
                                    .symbolEffect(.pulse, isActive: pipVoice.isSpeaking)
                                Text("Preview Pip's Voice")
                            }
                            .font(.AppTheme.subheadline)
                            .foregroundColor(Color.AppTheme.goldenWheat)
                        }
                        .buttonStyle(.plain)
                    }
                    .opacity(showContent ? 1 : 0)

                    // Next button
                    Button(action: onNext) {
                        HStack {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppSpacing.xl)
                    .opacity(showContent ? 1 : 0)

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
    }

}

#Preview {
    FamilySetupView()
        .environmentObject(SessionManager())
        .environmentObject(GameState())
        .environmentObject(AvatarModel())
        .environmentObject(AuthManager())
}
