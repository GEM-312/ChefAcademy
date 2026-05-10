import SwiftUI

// MARK: - Recipe Detail View (Pip's Cookbook Page)
struct RecipeDetailView: View {
    let recipe: Recipe
    var onStartCooking: (() -> Void)? = nil
    var childAllergens: [FoodAllergen] = []
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    private var matchingAllergens: [FoodAllergen] {
        recipe.matchingAllergens(childAllergens)
    }

    var body: some View {
        ZStack {
            Color.AppTheme.cream
                .ignoresSafeArea()

            // Sticky-footer pattern: ScrollView is bounded by the VStack so
            // "Let's Cook!" lives BELOW the scroll, always visible. Kids who
            // never scroll past the recipe steps still see the primary CTA.
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                    // MARK: - Hero Image
                    ZStack(alignment: .topTrailing) {
                        AssetPackImage(recipe.imageName, in: .recipes)
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .offset(y: recipe.imageYOffset)
                            .clipped()

                        // Dismiss button
                        Button(action: { if let onDismiss { onDismiss() } else { dismiss() } }) {
                            Image(systemName: "xmark")
                                .font(.AppTheme.rounded(size: 16, weight: .bold))
                                .foregroundColor(Color.AppTheme.darkBrown)
                                .frame(width: 44, height: 44)
                                .background(Color.AppTheme.cream.opacity(0.9))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(AppSpacing.md)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.md) {

                        // MARK: - Title Block
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            // Adult help badge
                            if recipe.needsAdultHelp {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                    Text("Adult Help Needed")
                                }
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.cream)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.AppTheme.terracotta)
                                .cornerRadius(10)
                            }

                            // Allergen warning banner
                            if !matchingAllergens.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.white)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Allergen Warning")
                                            .font(.AppTheme.caption)
                                            .fontWeight(.semibold)
                                        Text("Contains: \(matchingAllergens.map(\.displayName).joined(separator: ", "))")
                                            .font(.AppTheme.caption)
                                    }
                                    .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.AppTheme.terracotta)
                                .cornerRadius(AppSpacing.smallCornerRadius)
                            }

                            Text(recipe.title)
                                .font(.AppTheme.title)
                                .foregroundColor(Color.AppTheme.darkBrown)

                            Text(recipe.description)
                                .font(.AppTheme.subheadline)
                                .foregroundColor(Color.AppTheme.sepia)

                            // Metadata inline with title block
                            HStack(spacing: AppSpacing.sm) {
                                DifficultyBadge(level: recipe.difficulty)

                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                    Text("\(recipe.cookTime) min")
                                }
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.lightSepia)

                                HStack(spacing: 4) {
                                    Image(systemName: "person.2")
                                    Text("\(recipe.servings) servings")
                                }
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.lightSepia)

                                Spacer()
                            }
                        }

                        // MARK: - Pip's Tip
                        if !recipe.glucoseTip.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.AppTheme.captionLarge)
                                    .foregroundColor(Color.AppTheme.goldenWheat)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pip's Tip")
                                        .font(.AppTheme.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                    Text(recipe.glucoseTip)
                                        .font(.AppTheme.caption)
                                        .foregroundColor(Color.AppTheme.sepia)
                                }
                            }
                            .padding(AppSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.AppTheme.goldenWheat.opacity(0.1))
                            .cornerRadius(AppSpacing.smallCornerRadius)
                        }

                        // MARK: - Garden Ingredients
                        if !recipe.gardenIngredients.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label {
                                    Text("From Your Garden")
                                        .font(.AppTheme.headline)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                } icon: {
                                    Image(systemName: "leaf.fill")
                                        .foregroundColor(Color.AppTheme.sage)
                                }

                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 100), spacing: AppSpacing.sm)
                                ], spacing: AppSpacing.sm) {
                                    ForEach(recipe.gardenIngredients, id: \.self) { veg in
                                        HStack(spacing: 6) {
                                            Image(veg.imageName)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 28, height: 28)
                                            Text(veg.displayName)
                                                .font(.AppTheme.subheadline)
                                                .foregroundColor(Color.AppTheme.darkBrown)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.AppTheme.sage.opacity(0.1))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }

                        // MARK: - Pantry Ingredients
                        if !recipe.pantryIngredients.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label {
                                    Text("From the Pantry")
                                        .font(.AppTheme.headline)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                } icon: {
                                    Image(systemName: "cart.fill")
                                        .foregroundColor(Color.AppTheme.goldenWheat)
                                }

                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 100), spacing: AppSpacing.sm)
                                ], spacing: AppSpacing.sm) {
                                    ForEach(recipe.pantryIngredients, id: \.self) { item in
                                        HStack(spacing: 6) {
                                            Image(item.imageName)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 24, height: 24)
                                            Text(item.displayName)
                                                .font(.AppTheme.subheadline)
                                                .foregroundColor(Color.AppTheme.darkBrown)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.AppTheme.goldenWheat.opacity(0.1))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }

                        // MARK: - Cooking Steps
                        if !recipe.steps.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label {
                                    Text("Cooking Steps")
                                        .font(.AppTheme.headline)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                } icon: {
                                    Image(systemName: "list.number")
                                        .foregroundColor(Color.AppTheme.terracotta)
                                }

                                VStack(spacing: AppSpacing.sm) {
                                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                                            // Step number circle
                                            Text("\(index + 1)")
                                                .font(.AppTheme.headline)
                                                .foregroundColor(Color.AppTheme.cream)
                                                .frame(width: 32, height: 32)
                                                .background(Color.AppTheme.terracotta)
                                                .clipShape(Circle())

                                            Text(step)
                                                .font(.AppTheme.body)
                                                .foregroundColor(Color.AppTheme.darkBrown)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(AppSpacing.sm)
                                        .background(Color.AppTheme.warmCream)
                                        .cornerRadius(AppSpacing.smallCornerRadius)
                                    }
                                }
                            }
                        }

                        // MARK: - Nutrition Facts
                        if !recipe.nutritionFacts.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label {
                                    Text("Nutrition")
                                        .font(.AppTheme.headline)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                } icon: {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(Color.AppTheme.sage)
                                }

                                FlowLayout(spacing: AppSpacing.xs) {
                                    ForEach(recipe.nutritionFacts, id: \.self) { fact in
                                        Text(fact)
                                            .font(.AppTheme.caption)
                                            .foregroundColor(Color.AppTheme.darkBrown)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.AppTheme.sage.opacity(0.15))
                                            .cornerRadius(14)
                                    }
                                }
                            }
                        }

                        Spacer().frame(height: AppSpacing.lg)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
                }
            }

                // MARK: - Sticky "Let's Cook!" Footer
                // Lives outside the ScrollView so 6yr olds always see the
                // primary CTA — no scrolling-past-everything required.
                Button(action: {
                    if let onDismiss { onDismiss() } else { dismiss() }
                    onStartCooking?()
                }) {
                    Text("Let's Cook!")
                }
                .buttonStyle(TexturedButtonStyle(tint: Color.AppTheme.sage))
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(Color.AppTheme.cream)
            }
        }
    }
}

// MARK: - Flow Layout (wrapping horizontal layout for pills)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            ), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Preview
#Preview {
    RecipeDetailView(recipe: GardenRecipes.all[0])
}
