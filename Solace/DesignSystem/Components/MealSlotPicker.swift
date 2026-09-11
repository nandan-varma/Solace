import SwiftUI

/// Shared selection behavior and stable sizing for every logging flow.
struct MealSlotPicker: View {
    @Binding var selection: MealSlot

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: Spacing.sm) {
            ForEach(MealSlot.allCases) { slot in
                Button { selection = slot } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: slot.icon)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .opacity(selection == slot ? 1 : 0)
                        }
                        Text(slot.displayName).font(.solaceLabel)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .foregroundStyle(selection == slot ? slot.tint : .primary)
                    .background(selection == slot ? slot.tint.opacity(0.16) : Color.solaceFill,
                                in: RoundedRectangle(cornerRadius: Corner.sm))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(slot.displayName)
                .accessibilityAddTraits(selection == slot ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
