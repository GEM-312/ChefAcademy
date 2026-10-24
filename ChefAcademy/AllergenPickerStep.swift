//
//  AllergenPickerStep.swift
//  ChefAcademy
//
//  Reusable allergen selection grid — used in onboarding, add child flow,
//  and parent dashboard editor. Parents pick their child's food allergens.
//

import SwiftUI

struct AllergenPickerStep: View {
    let title: String
    let subtitle: String
    @Binding var selectedAllergens: [FoodAllergen]
    let onNext: () -> Void
    let onBack: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer().frame(height: AppSpacing.md)

            // Header
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                    .multilineTextAlignment(.center)

                Text("You can change this later in the Parent Dashboard.")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.lightSepia)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.xxs)
            }
            .padding(.horizontal, AppSpacing.lg)

            // Allergen grid
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                    ForEach(FoodAllergen.allCases) { allergen in
                        AllergenToggleButton(
                            allergen: allergen,
                            isSelected: selectedAllergens.contains(allergen),
                            onTap: { toggleAllergen(allergen) }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // "None of these" button
                Button(action: {
                    selectedAllergens = []
                    onNext()
                }) {
                    Text("None of these")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sage)
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.top, AppSpacing.md)
            }

            // Navigation buttons — same wood buttons as the other setup steps
            HStack(spacing: AppSpacing.md) {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Text("Back")
                    }
                    .backButton()
                }

                Button(action: onNext) {
                    HStack {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                }
                .primaryButton()
            }
            .padding(AppSpacing.md)
        }
    }

    private func toggleAllergen(_ allergen: FoodAllergen) {
        if let index = selectedAllergens.firstIndex(of: allergen) {
            selectedAllergens.remove(at: index)
        } else {
            selectedAllergens.append(allergen)
        }
    }
}

// MARK: - Allergen Toggle Button

struct AllergenToggleButton: View {
    let allergen: FoodAllergen
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.xs) {
                Text(allergen.emoji)
                    .font(.AppTheme.title)

                Text(allergen.displayName)
                    .font(.AppTheme.microLarge.weight(.medium))
                    .foregroundColor(isSelected ? Color.AppTheme.darkBrown : Color.AppTheme.sepia)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.AppTheme.captionLarge)
                    .foregroundColor(isSelected ? Color.AppTheme.terracotta : Color.AppTheme.lightSepia)
            }
        }
        // Shared pick-card look: terracotta = "careful" (an allergen to avoid)
        .choiceCard(tint: Color.AppTheme.terracotta, isSelected: isSelected, padding: AppSpacing.sm)
    }
}

#Preview {
    AllergenPickerStep(
        title: "Any food allergies?",
        subtitle: "Select any allergens for Emma",
        selectedAllergens: .constant([.milk, .eggs]),
        onNext: {},
        onBack: {}
    )
    .background(Color.AppTheme.cream)
}
