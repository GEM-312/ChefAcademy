//
//  FamilySetupView.swift
//  ChefAcademy
//
//  First-launch wizard: creates parent + first child profiles.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Family Setup Manager

class FamilySetupManager: ObservableObject {
    @Published var step: SetupStep = .welcome

    // Parent data
    @Published var parentName: String = ""
    @Published var parentGender: Gender = .girl
    @Published var parentOutfit: Outfit = .chefWhite
    @Published var parentHeadCovering: HeadCovering = .none
    @Published var parentPIN: String = ""

    // Child data
    @Published var childName: String = ""
    @Published var childGender: Gender = .girl
    @Published var childOutfit: Outfit = .apronRed
    @Published var childHeadCovering: HeadCovering = .none

    enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case parentName = 1
        case parentAvatar = 2
        case setPIN = 3
        case childName = 4
        case childAvatar = 5
        case meetPip = 6
        case ready = 7
    }

    func nextStep() {
        let all = SetupStep.allCases
        if let idx = all.firstIndex(of: step), idx < all.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                step = all[idx + 1]
            }
        }
    }

    func previousStep() {
        let all = SetupStep.allCases
        if let idx = all.firstIndex(of: step), idx > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
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

            case .parentAvatar:
                FamilyAvatarStep(
                    title: "Create your chef!",
                    gender: $setupManager.parentGender,
                    outfit: $setupManager.parentOutfit,
                    headCovering: $setupManager.parentHeadCovering,
                    onNext: { setupManager.nextStep() },
                    onBack: { setupManager.previousStep() }
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
        let family = FamilyProfile(parentPIN: "")
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

            Image("pip_neutral")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.AppTheme.sage, lineWidth: 3))
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)

            VStack(spacing: AppSpacing.sm) {
                Text("Welcome to")
                    .font(.AppTheme.title2)
                    .foregroundColor(Color.AppTheme.sepia)
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

    // Temporary avatar model for preview
    @StateObject private var tempAvatar = AvatarModel()

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.AppTheme.title)
                .foregroundColor(Color.AppTheme.darkBrown)
                .padding(.top, AppSpacing.lg)

            // Gender selection
            HStack(spacing: AppSpacing.lg) {
                ForEach(Gender.allCases) { g in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            gender = g
                            tempAvatar.gender = g
                        }
                    }) {
                        VStack(spacing: 4) {
                            let img = g == .boy ? "boy_card_frame_28" : "girl_card_frame_15"
                            Image(img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())

                            Text(g.rawValue)
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.darkBrown)
                        }
                        .padding(AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(gender == g ? Color.AppTheme.sage.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(gender == g ? Color.AppTheme.sage : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, AppSpacing.sm)

            // Outfit + Covering selectors
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    OutfitSelector(selectedOutfit: $outfit)
                    HeadCoveringSelector(selectedCovering: $headCovering)
                }
                .padding(AppSpacing.md)
            }
            .background(Color.AppTheme.parchment)
            .cornerRadius(AppSpacing.cardCornerRadius, corners: [.topLeft, .topRight])

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
        .onAppear {
            tempAvatar.gender = gender
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

            Image("pip_thinking")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())

            VStack(spacing: AppSpacing.xs) {
                Text(isConfirming ? "Confirm Your PIN" : "Set a Parent PIN")
                    .font(.AppTheme.title2)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text(isConfirming ? "Enter the same 4 digits" : "Only grown-ups need to know this!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }

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
                    .foregroundColor(.red)
            }

            Spacer()

            // Number pad
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 20) {
                        ForEach(1...3, id: \.self) { col in
                            let num = row * 3 + col
                            PINButton(label: "\(num)") { appendDigit("\(num)") }
                        }
                    }
                }

                HStack(spacing: 20) {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: 75, height: 55)
                    }

                    PINButton(label: "0") { appendDigit("0") }

                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: 75, height: 55)
                    }
                }
            }
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
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { shake = true }
                    showError = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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

    private var dialogues: [String] {
        [
            "Hello there, \(childName)!",
            "I'm Pip, and this is my Kitchen Garden!",
            "I'm so excited to cook with you!",
            "Together, we'll grow yummy vegetables...",
            "...and cook delicious healthy meals!",
            "Are you ready to become a super chef?"
        ]
    }

    var body: some View {
        ZStack {
            CottageBackground()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                PipWavingAnimatedView(size: 160)
                    .scaleEffect(showPip ? 1 : 0.3)
                    .opacity(showPip ? 1 : 0)

                VStack(spacing: AppSpacing.md) {
                    Text("Pip")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(20)

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
                            Text("Yes! Let's Go!")
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
            withAnimation(.easeOut(duration: 0.15)) { showDialogue = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dialogueIndex += 1
                withAnimation(.easeIn(duration: 0.2)) { showDialogue = true }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { showPip = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.3)) { showDialogue = true }
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

            PipWavingAnimatedView(size: 140)
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                FeatureRow(icon: "leaf.fill", text: "Grow vegetables in Pip's garden", systemIcon: true)
                FeatureRow(icon: "fork.knife", text: "Cook yummy healthy recipes", systemIcon: true)
                FeatureRow(icon: "figure.child", text: "Feed your Body Buddy", systemIcon: true)
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

#Preview {
    FamilySetupView()
        .environmentObject(SessionManager())
        .environmentObject(GameState())
        .environmentObject(AvatarModel())
}
