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
                    .padding(.top, 2)
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
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.md)
            }

            // Navigation buttons
            HStack(spacing: AppSpacing.md) {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.sepia)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.sm)
                            .background(Color.AppTheme.warmCream)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                    .stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onNext) {
                    Text("Next")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.sm)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, AppSpacing.lg)
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
            VStack(spacing: 6) {
                Text(allergen.emoji)
                    .font(.AppTheme.title)

                Text(allergen.displayName)
                    .font(.AppTheme.rounded(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.AppTheme.sepia)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.AppTheme.captionLarge)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "circle")
                        .font(.AppTheme.captionLarge)
                        .foregroundColor(Color.AppTheme.lightSepia)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? Color.AppTheme.terracotta : Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .stroke(isSelected ? Color.AppTheme.terracotta : Color.AppTheme.sepia.opacity(0.2), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(AnimationConstants.springQuick, value: isSelected)
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
