import SwiftUI

struct PostComposerSheet: View {
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Text("New Post")
                    .font(.headline)

                Spacer()

                Button("Post") {
                    onSubmit(content)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            Divider()

            // Editor
            TextEditor(text: $content)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding()
                .frame(minHeight: 150)

            Divider()

            // Footer
            HStack {
                Text("\(content.count) characters")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 520, height: 340)
    }
}

#Preview {
    PostComposerSheet { _ in }
}
