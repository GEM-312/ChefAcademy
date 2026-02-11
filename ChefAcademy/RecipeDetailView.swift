import SwiftUI

// MARK: - Recipe Detail View (Pip's Cookbook Page)
struct RecipeDetailView: View {
    let recipe: Recipe
    var onStartCooking: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.AppTheme.cream
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: - Hero Image
                    ZStack(alignment: .topTrailing) {
                        Image(recipe.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 250)
                            .offset(y: recipe.imageYOffset)
                            .clipped()

                        // Dismiss button
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.AppTheme.darkBrown)
                                .frame(width: 44, height: 44)
                                .background(Color.AppTheme.cream.opacity(0.9))
                                .clipShape(Circle())
                        }
                        .padding(AppSpacing.md)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.lg) {

                        // MARK: - Title Block
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
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

                            Text(recipe.title)
                                .font(.AppTheme.largeTitle)
                                .foregroundColor(Color.AppTheme.darkBrown)

                            Text(recipe.description)
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sepia)
                        }

                        // MARK: - Metadata Row
                        HStack(spacing: AppSpacing.md) {
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

                        // MARK: - Pip's Tip
                        if !recipe.glucoseTip.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.AppTheme.goldenWheat)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pip's Tip")
                                        .font(.AppTheme.headline)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                    Text(recipe.glucoseTip)
                                        .font(.AppTheme.body)
                                        .foregroundColor(Color.AppTheme.sepia)
                                }
                            }
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.AppTheme.goldenWheat.opacity(0.1))
                            .cornerRadius(AppSpacing.cardCornerRadius)
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
                                            Text(item.emoji)
                                                .font(.system(size: 20))
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
                                        .cornerRadius(12)
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

                        // MARK: - Let's Cook Button
                        Button(action: {
                            dismiss()
                            onStartCooking?()
                        }) {
                            Text("Let's Cook!")
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.cream)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.AppTheme.sage)
                                .cornerRadius(AppSpacing.cardCornerRadius)
                        }
                        .padding(.top, AppSpacing.sm)

                        Spacer().frame(height: AppSpacing.xl)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                }
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
