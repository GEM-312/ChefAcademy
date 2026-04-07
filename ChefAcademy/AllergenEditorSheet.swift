//
//  AllergenEditorSheet.swift
//  ChefAcademy
//
//  Parent Dashboard sheet for editing a child's food allergens.
//  Also includes the "Strict Mode" toggle to hide allergen recipes entirely.
//

import SwiftUI
import SwiftData

struct AllergenEditorSheet: View {
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var gameState: GameState

    @State private var selectedAllergens: [FoodAllergen] = []
    @State private var strictMode: Bool = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.AppTheme.cream.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        // Header
                        VStack(spacing: AppSpacing.sm) {
                            Text("Food Allergies")
                                .font(.AppTheme.title)
                                .foregroundColor(Color.AppTheme.darkBrown)

                            Text("Select \(profile.name)'s allergens")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sepia)
                        }

                        // Allergen grid
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

                        // Strict Mode toggle
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Toggle(isOn: $strictMode) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Strict Mode")
                                        .font(.AppTheme.headline)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                    Text("Hide recipes with allergens completely instead of just warning")
                                        .font(.AppTheme.caption)
                                        .foregroundColor(Color.AppTheme.lightSepia)
                                }
                            }
                            .tint(Color.AppTheme.terracotta)
                        }
                        .padding(AppSpacing.md)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                        .padding(.horizontal, AppSpacing.md)

                        // Clear all button
                        if !selectedAllergens.isEmpty {
                            Button(action: { selectedAllergens = [] }) {
                                Text("Clear All")
                                    .font(.AppTheme.body)
                                    .foregroundColor(Color.AppTheme.terracotta)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.top, AppSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.AppTheme.sepia)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .foregroundColor(Color.AppTheme.sage)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selectedAllergens = profile.allergens
            strictMode = profile.allergenStrictMode
        }
    }

    private func toggleAllergen(_ allergen: FoodAllergen) {
        if let index = selectedAllergens.firstIndex(of: allergen) {
            selectedAllergens.remove(at: index)
        } else {
            selectedAllergens.append(allergen)
        }
    }

    private func saveAndDismiss() {
        profile.setAllergens(selectedAllergens)
        profile.allergenStrictMode = strictMode
        try? modelContext.save()

        // Update active GameState if this is the current player
        if gameState.activeProfileID == profile.id {
            gameState.activeAllergens = selectedAllergens
            gameState.allergenStrictMode = strictMode
        }

        dismiss()
    }
}
