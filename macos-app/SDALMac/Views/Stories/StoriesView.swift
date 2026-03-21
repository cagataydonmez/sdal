import SwiftUI

struct StoriesView: View {
    @State private var viewModel = StoriesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.error {
                ErrorBanner(message: error) { await viewModel.refresh() }
            }

            if viewModel.isLoading && viewModel.stories.isEmpty {
                LoadingView(message: "Loading stories...")
            } else if viewModel.stories.isEmpty {
                EmptyStateView(icon: "camera", title: "No stories", message: "Stories appear here for 24 hours.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.storyGroups, id: \.userId) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    if let first = group.stories.first {
                                        AvatarView(url: first.authorPhotoURL, initials: first.initials, size: 32)
                                    }
                                    Text(group.userName).font(.callout).fontWeight(.semibold)
                                    Text("\(group.stories.count) stories").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(group.stories) { story in
                                            StoryThumbnail(story: story) {
                                                viewModel.selectedStory = story
                                                Task { await viewModel.markViewed(story.id) }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Stories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await viewModel.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh stories")
            }
        }
        .sheet(item: $viewModel.selectedStory) { story in
            StoryDetailSheet(story: story)
        }
        .task { await viewModel.loadStories() }
    }
}

struct StoryThumbnail: View {
    let story: Story
    var onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            ZStack(alignment: .bottomLeading) {
                if let url = story.imageURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                    }
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }

                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)

                if let caption = story.caption, !caption.isEmpty {
                    Text(caption).font(.caption2).foregroundStyle(.white).lineLimit(2).padding(8)
                }

                if story.viewed != true {
                    Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: 140, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .help(story.relativeTime)
    }
}

struct StoryDetailSheet: View {
    let story: Story
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AvatarView(url: story.authorPhotoURL, initials: story.initials, size: 32)
                VStack(alignment: .leading) {
                    Text(story.authorDisplayName).font(.callout).fontWeight(.semibold)
                    Text(story.relativeTime).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding()

            if let url = story.imageURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 500)
                    } else {
                        ProgressView().frame(height: 300)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }

            if let caption = story.caption, !caption.isEmpty {
                Text(caption).font(.body).padding().textSelection(.enabled)
            }

            Spacer()
        }
        .frame(width: 500, height: 650)
    }
}

