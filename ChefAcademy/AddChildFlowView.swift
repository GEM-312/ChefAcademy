//
//  AddChildFlowView.swift
//  ChefAcademy
//
//  Shorter flow for adding subsequent children from the profile picker.
//  Steps: Name → Avatar → Quick Meet Pip → Done
//

import SwiftUI
import SwiftData

struct AddChildFlowView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var avatarModel: AvatarModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var step: Int = 0
    @State private var childName: String = ""
    @State private var childGender: Gender = .girl
    @State private var childOutfit: Outfit = .apronRed
    @State private var childHeadCovering: HeadCovering = .none
    @State private var showDuplicateWarning: Bool = false

    /// Check if a child with this name already exists in the family
    private var nameAlreadyExists: Bool {
        guard let family = sessionManager.familyProfile else { return false }
        let trimmed = childName.trimmingCharacters(in: .whitespaces).lowercased()
        return family.childProfiles(in: modelContext).contains {
            $0.name.lowercased() == trimmed
        }
    }

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            switch step {
            case 0:
                VStack(spacing: 0) {
                    FamilyNameStep(
                        title: "Add a Little Chef!",
                        subtitle: "What's their name?",
                        name: $childName,
                        onNext: {
                            if nameAlreadyExists {
                                showDuplicateWarning = true
                            } else {
                                withAnimation { step = 1 }
                            }
                        },
                        onBack: { dismiss() }
                    )
                }
                .alert("Name Already Taken", isPresented: $showDuplicateWarning) {
                    Button("OK") { }
                } message: {
                    Text("There's already a little chef named \"\(childName)\" in this family. Please choose a different name!")
                }

            case 1:
                FamilyAvatarStep(
                    title: "Create their chef!",
                    gender: $childGender,
                    outfit: $childOutfit,
                    headCovering: $childHeadCovering,
                    onNext: { withAnimation { step = 2 } },
                    onBack: { withAnimation { step = 0 } }
                )

            case 2:
                // Quick Meet Pip
                VStack(spacing: AppSpacing.xl) {
                    Spacer()

                    PipWavingAnimatedView(size: 140)

                    VStack(spacing: AppSpacing.sm) {
                        Text("Welcome, \(childName)!")
                            .font(.AppTheme.largeTitle)
                            .foregroundColor(Color.AppTheme.darkBrown)

                        Text("Pip can't wait to cook with you!")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                    }

                    Spacer()

                    Button(action: { finishAddChild() }) {
                        HStack {
                            Text("Let's Go!")
                            Image(systemName: "arrow.right.circle.fill")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppSpacing.xl)

                    Spacer().frame(height: AppSpacing.xxl)
                }

            default:
                EmptyView()
            }
        }
    }

    private func finishAddChild() {
        _ = sessionManager.addChildProfile(
            name: childName,
            gender: childGender,
            headCovering: childHeadCovering,
            outfit: childOutfit
        )
        dismiss()
    }
}

#Preview {
    AddChildFlowView()
        .environmentObject(SessionManager())
        .environmentObject(GameState())
        .environmentObject(AvatarModel())
}
