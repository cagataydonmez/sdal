import SwiftUI

struct StoriesView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        Group {
            switch viewModel.storiesState {
            case .idle, .loading:
                LoadingView()
            case .failed(let msg):
                ErrorRetryView(message: msg) {
                    Task { await viewModel.loadStories(cookie: cookie, baseUrl: baseUrl) }
                }
            case .loaded(let stories):
                if stories.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "circle.dashed")
                            .foregroundStyle(.secondary)
                        Text("Hikaye yok")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    storyList(stories)
                }
            }
        }
        .navigationTitle("Hikayeler")
        .task {
            // Always load fresh on appear
            await viewModel.loadStories(cookie: cookie, baseUrl: baseUrl)
        }
    }

    private func storyList(_ stories: [WatchStory]) -> some View {
        List(stories) { story in
            NavigationLink(destination: StoryDetailView(story: story)) {
                HStack(spacing: 8) {
                    AvatarView(
                        initials: story.initials,
                        photoUrl: story.authorPhoto,
                        size: 34,
                        ringColor: story.viewed ? nil : .accentColor
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(story.authorName.isEmpty ? "@\(story.authorHandle)" : story.authorName)
                            .font(.caption2)
                            .fontWeight(story.viewed ? .regular : .semibold)
                            .lineLimit(1)
                        if !story.caption.isEmpty {
                            Text(story.caption)
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if !story.createdAt.isEmpty {
                            Text(relativeTime(story.createdAt))
                                .font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.carousel)
        .refreshable {
            await viewModel.loadStories(cookie: cookie, baseUrl: baseUrl)
        }
    }
}

// MARK: - Story Detail

struct StoryDetailView: View {
    let story: WatchStory

    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full image
            if !story.fullUrl.isEmpty {
                AsyncImage(url: URL(string: story.fullUrl)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                    case .failure:
                        Color.black
                    default:
                        Color.black.overlay(ProgressView())
                    }
                }
                .ignoresSafeArea()
            } else {
                // No image — show initials as placeholder
                ZStack {
                    Color.black.ignoresSafeArea()
                    AvatarView(initials: story.initials, photoUrl: story.authorPhoto, size: 60)
                }
            }

            // Caption overlay
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    AvatarView(initials: story.initials, photoUrl: story.authorPhoto, size: 24)
                    Text(story.authorName.isEmpty ? "@\(story.authorHandle)" : story.authorName)
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(.white).shadow(radius: 2)
                }
                if !story.caption.isEmpty {
                    Text(story.caption)
                        .font(.caption2)
                        .foregroundStyle(.white).shadow(radius: 2)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .padding(8)
            .background(.black.opacity(0.45))
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            Task {
                await viewModel.markStoryViewed(
                    storyId: story.id,
                    cookie: sessionManager.sessionCookie,
                    baseUrl: sessionManager.apiBaseUrl
                )
            }
        }
    }
}
