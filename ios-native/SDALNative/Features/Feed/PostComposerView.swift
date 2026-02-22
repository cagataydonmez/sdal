import SwiftUI
import PhotosUI

@MainActor
struct PostComposerView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let onPostCreated: () async -> Void

    @State private var content = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showCamera = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var composerFeedback: String?

    private let api = APIClient.shared

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(i18n.t("create_post"))
                    .font(.headline)

                TextField(i18n.t("post_placeholder"), text: $content, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)

                if isCompactEditor {
                    Menu {
                        toolbarButton("Bold", prefix: "**", suffix: "**")
                        toolbarButton("Italic", prefix: "_", suffix: "_")
                        toolbarButton("Mention", prefix: "@", suffix: "")
                        toolbarButton("Link", prefix: "[text](", suffix: ")")
                    } label: {
                        Label("Editor Tools", systemImage: "textformat")
                    }
                    .buttonStyle(.bordered)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            toolbarButton("B", prefix: "**", suffix: "**")
                            toolbarButton("I", prefix: "_", suffix: "_")
                            toolbarButton("@", prefix: "@", suffix: "")
                            toolbarButton("Link", prefix: "[text](", suffix: ")")
                        }
                    }
                }

                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack {
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        Label(imageData == nil ? i18n.t("add_photo") : i18n.t("change_photo"), systemImage: "photo")
                    }
                    .buttonStyle(.bordered)

                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showCamera = true
                        } label: {
                            Label(i18n.t("camera"), systemImage: "camera")
                        }
                        .buttonStyle(.bordered)
                    }

                    if imageData != nil {
                        Button(i18n.t("remove")) { imageData = nil }
                            .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(i18n.t("share"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || (content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageData == nil))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let composerFeedback {
                    GlobalActionFeedbackChip(message: composerFeedback)
                }
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task {
                imageData = try? await newValue.loadTransferable(type: Data.self)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCapturePicker { data in
                if let data {
                    imageData = data
                }
                showCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            if let imageData {
                _ = try await api.createPostWithImage(
                    content: content,
                    imageData: imageData,
                    fileName: "post.jpg",
                    mimeType: "image/jpeg",
                    filter: ""
                )
            } else {
                _ = try await api.createPost(content: content)
            }
            content = ""
            imageData = nil
            composerFeedback = "Post shared"
            await onPostCreated()
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                await MainActor.run {
                    composerFeedback = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func toolbarButton(_ label: String, prefix: String, suffix: String) -> some View {
        Button(label) {
            insertToken(prefix: prefix, suffix: suffix)
        }
        .buttonStyle(.bordered)
    }

    private func insertToken(prefix: String, suffix: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            content = prefix + suffix
        } else {
            content += " \(prefix)\(suffix)"
        }
    }

    private var isCompactEditor: Bool {
        horizontalSizeClass == .compact
    }
}
