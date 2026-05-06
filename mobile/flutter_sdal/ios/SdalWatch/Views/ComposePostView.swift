import SwiftUI

struct ComposePostView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var content = ""
    @State private var feedType = "main"
    @State private var isPosting = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Yeni gönderi")
                    .font(.caption2).fontWeight(.semibold)

                TextField("Ne düşünüyorsunuz?", text: $content, axis: .vertical)
                    .font(.caption2)
                    .lineLimit(5)
                    .frame(minHeight: 60, alignment: .topLeading)

                Picker("Akış", selection: $feedType) {
                    Text("Genel").tag("main")
                    Text("Topluluk").tag("community")
                }
                .pickerStyle(.wheel)
                .frame(height: 44)

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Button("İptal") { dismiss() }
                        .font(.caption2)
                        .buttonStyle(.bordered)

                    Button("Gönder") {
                        Task { await post() }
                    }
                    .font(.caption2)
                    .buttonStyle(.borderedProminent)
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty || isPosting)
                }
            }
            .padding()
        }
    }

    private func post() async {
        let text = content.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isPosting = true
        errorMessage = nil
        do {
            try await viewModel.createPost(
                content: text,
                feedType: feedType,
                cookie: sessionManager.sessionCookie,
                baseUrl: sessionManager.apiBaseUrl
            )
            dismiss()
        } catch {
            errorMessage = "Gönderilemedi. Tekrar dene."
        }
        isPosting = false
    }
}
