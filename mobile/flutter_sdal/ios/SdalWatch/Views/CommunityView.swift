import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    @State private var selectedTab = 0

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        VStack(spacing: 0) {
            communityTabSelector
            if selectedTab == 0 {
                AnnouncementsTab()
            } else {
                EventsTab()
            }
        }
        .navigationTitle("Topluluk")
    }

    private var communityTabSelector: some View {
        HStack(spacing: 0) {
            communityTab(title: "Duyurular", idx: 0)
            communityTab(title: "Etkinlikler", idx: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private func communityTab(title: String, idx: Int) -> some View {
        Button {
            selectedTab = idx
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(selectedTab == idx ? Color.accentColor : Color.clear)
                .foregroundStyle(selectedTab == idx ? .white : Color.primary.opacity(0.55))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Announcements Tab

private struct AnnouncementsTab: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        Group {
            switch viewModel.announcementsState {
            case .idle, .loading:
                LoadingView()
            case .failed(let msg):
                ErrorRetryView(message: msg) {
                    Task { await viewModel.loadAnnouncements(cookie: cookie, baseUrl: baseUrl) }
                }
            case .loaded(let items):
                if items.isEmpty {
                    emptyView
                } else {
                    announcementList(items)
                }
            }
        }
        .task {
            if viewModel.announcementsState.value == nil {
                await viewModel.loadAnnouncements(cookie: cookie, baseUrl: baseUrl)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "megaphone")
                .font(.system(size: 26))
                .foregroundStyle(Color.accentColor.opacity(0.5))
            Text("Duyuru yok")
                .font(.system(size: 12, weight: .medium))
            Text("Henüz bir duyuru paylaşılmadı")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func announcementList(_ items: [WatchAnnouncement]) -> some View {
        List(items) { item in
            NavigationLink(destination: AnnouncementDetailView(item: item)) {
                AnnouncementRow(item: item)
            }
        }
        .listStyle(.carousel)
        .refreshable {
            await viewModel.loadAnnouncements(cookie: cookie, baseUrl: baseUrl)
        }
    }
}

// MARK: - Announcement Row

struct AnnouncementRow: View {
    let item: WatchAnnouncement

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.accentColor)
                Text(!item.creatorHandle.isEmpty ? "@\(item.creatorHandle)" : "SDAL")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                Spacer()
                let ts = item.publishedAt.isEmpty ? item.createdAt : item.publishedAt
                if !ts.isEmpty {
                    Text(relativeTime(ts))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            Text(item.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
            if !item.body.isEmpty {
                Text(item.body)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Announcement Detail

struct AnnouncementDetailView: View {
    let item: WatchAnnouncement
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                    Text(!item.creatorHandle.isEmpty ? "@\(item.creatorHandle)" : "SDAL")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    let ts = item.publishedAt.isEmpty ? item.createdAt : item.publishedAt
                    if !ts.isEmpty {
                        Text(relativeTime(ts))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                if !item.imageUrl.isEmpty {
                    AsyncImage(url: resolvedMediaURL(item.imageUrl, baseUrl: sessionManager.apiBaseUrl)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            EmptyView()
                        default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 90)
                                .overlay(ProgressView().scaleEffect(0.6))
                        }
                    }
                }

                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .navigationTitle("Duyuru")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Events Tab

private struct EventsTab: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        Group {
            switch viewModel.eventsState {
            case .idle, .loading:
                LoadingView()
            case .failed(let msg):
                ErrorRetryView(message: msg) {
                    Task { await viewModel.loadEvents(cookie: cookie, baseUrl: baseUrl) }
                }
            case .loaded(let items):
                if items.isEmpty {
                    emptyView
                } else {
                    eventList(items)
                }
            }
        }
        .task {
            if viewModel.eventsState.value == nil {
                await viewModel.loadEvents(cookie: cookie, baseUrl: baseUrl)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 26))
                .foregroundStyle(Color.accentColor.opacity(0.5))
            Text("Etkinlik yok")
                .font(.system(size: 12, weight: .medium))
            Text("Yaklaşan etkinlik bulunamadı")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func eventList(_ items: [WatchEvent]) -> some View {
        List(items) { item in
            NavigationLink(destination: EventDetailView(event: item)) {
                EventRow(event: item)
            }
        }
        .listStyle(.carousel)
        .refreshable {
            await viewModel.loadEvents(cookie: cookie, baseUrl: baseUrl)
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: WatchEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                rsvpDot
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
            }

            if !event.startsAt.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentColor)
                    Text(eventDateString(event.startsAt))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.7))
                        .lineLimit(1)
                }
            }

            if !event.location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentColor)
                    Text(event.location)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.7))
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.4))
                    Text("\(event.attendCount)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var rsvpDot: some View {
        switch event.myResponse {
        case "attend":
            Circle().fill(Color.accentColor).frame(width: 6, height: 6)
        case "decline":
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
        default:
            EmptyView()
        }
    }
}

// MARK: - Event Detail

struct EventDetailView: View {
    let event: WatchEvent

    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @State private var isResponding = false
    @State private var responseError: String? = nil

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    private var currentEvent: WatchEvent {
        viewModel.eventsState.value?.first(where: { $0.id == event.id }) ?? event
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(currentEvent.title)
                    .font(.system(size: 14, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                if !currentEvent.imageUrl.isEmpty {
                    AsyncImage(url: resolvedMediaURL(currentEvent.imageUrl, baseUrl: sessionManager.apiBaseUrl)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            EmptyView()
                        default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 90)
                                .overlay(ProgressView().scaleEffect(0.6))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if !currentEvent.startsAt.isEmpty {
                        metaRow(icon: "clock.fill", text: eventDateString(currentEvent.startsAt))
                    }
                    if !currentEvent.location.isEmpty {
                        metaRow(icon: "mappin.circle.fill", text: currentEvent.location)
                    }
                    if !currentEvent.creatorHandle.isEmpty {
                        metaRow(icon: "person.fill", text: "@\(currentEvent.creatorHandle)")
                    }
                }

                if !currentEvent.body.isEmpty {
                    Text(currentEvent.body)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }

                attendanceSummary

                rsvpButtons

                if let err = responseError {
                    Text(err)
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .navigationTitle("Etkinlik")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color.accentColor.opacity(0.8))
                .frame(width: 14)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.75))
                .lineLimit(2)
        }
    }

    private var attendanceSummary: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(currentEvent.attendCount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Text("Katılıyor")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 2) {
                Text("\(currentEvent.declineCount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.45))
                Text("Katılamıyor")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }

    private var rsvpButtons: some View {
        HStack(spacing: 6) {
            Button {
                Task { await respond("attend") }
            } label: {
                Label(
                    currentEvent.myResponse == "attend" ? "Katılıyorum" : "Katıl",
                    systemImage: currentEvent.myResponse == "attend" ? "checkmark.circle.fill" : "checkmark.circle"
                )
                .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(currentEvent.myResponse == "attend" ? Color.accentColor : Color.primary.opacity(0.2))
            .disabled(isResponding)

            Button {
                Task { await respond("decline") }
            } label: {
                Label(
                    currentEvent.myResponse == "decline" ? "Katılamam" : "Hayır",
                    systemImage: currentEvent.myResponse == "decline" ? "xmark.circle.fill" : "xmark.circle"
                )
                .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .disabled(isResponding)
        }
    }

    private func respond(_ response: String) async {
        isResponding = true
        responseError = nil
        do {
            try await viewModel.respondToEvent(
                eventId: currentEvent.id,
                response: response,
                cookie: cookie,
                baseUrl: baseUrl
            )
        } catch {
            responseError = "Yanıt gönderilemedi"
        }
        isResponding = false
    }
}

// MARK: - Event date formatter

func eventDateString(_ iso: String) -> String {
    guard let date = parseSdalDateForEvent(iso) else { return iso }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "tr_TR")
    formatter.timeZone = TimeZone.current
    let now = Date()
    let sameYear = Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: now)
    formatter.dateFormat = sameYear ? "d MMM, HH:mm" : "d MMM yyyy, HH:mm"
    return formatter.string(from: date)
}

private func parseSdalDateForEvent(_ raw: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = fractional.date(from: raw) { return d }
    let internet = ISO8601DateFormatter()
    internet.formatOptions = [.withInternetDateTime]
    if let d = internet.date(from: raw) { return d }
    let simple = DateFormatter()
    simple.locale = Locale(identifier: "tr_TR")
    simple.timeZone = TimeZone.current
    simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return simple.date(from: raw)
}
