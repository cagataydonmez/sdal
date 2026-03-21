import SwiftUI

struct EventsView: View {
    @State private var viewModel = EventsViewModel()
    @State private var selectedEvent: Event?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.events.isEmpty {
                    LoadingView(message: "Loading events...")
                } else if viewModel.events.isEmpty {
                    EmptyStateView(icon: "calendar", title: "No events", message: "There are no upcoming events.")
                } else {
                    List(viewModel.events, selection: $selectedEvent) { event in
                        EventListRow(event: event).tag(event)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            if let event = selectedEvent {
                EventDetailPanel(event: event) { response in
                    Task { await viewModel.respondToEvent(event.id, response: response) }
                }
            } else {
                EmptyStateView(icon: "calendar", title: "Select an event", message: "Choose an event to view details.")
            }
        }
        .navigationTitle("Events")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await viewModel.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh events")
            }
        }
        .task { await viewModel.loadEvents() }
    }
}

struct EventListRow: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            VStack {
                if let imageURL = event.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            calendarIcon
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    calendarIcon
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title ?? "Event").font(.callout).fontWeight(.medium).lineLimit(2)
                HStack(spacing: 4) {
                    Text(event.formattedDate).font(.caption).foregroundStyle(.secondary)
                    if let location = event.location, !location.isEmpty {
                        Text("· \(location)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                HStack(spacing: 8) {
                    if event.attendeeCount > 0 {
                        Label("\(event.attendeeCount)", systemImage: "person.2")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let response = event.myResponse {
                        Text(response == "attend" ? "Going" : "Declined")
                            .font(.caption2).fontWeight(.medium)
                            .foregroundStyle(response == "attend" ? .green : .secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var calendarIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: "calendar")
                .foregroundStyle(Color.accentColor)
        }
    }
}

struct EventDetailPanel: View {
    let event: Event
    var onRespond: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let imageURL = event.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 240).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 16)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(event.title ?? "Event").font(.title2).fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 8) {
                        if let startsAt = event.startsAt {
                            Label(DateFormatter.relativeString(from: startsAt), systemImage: "calendar").font(.callout)
                        }
                        if let location = event.location, !location.isEmpty {
                            Label(location, systemImage: "mappin").font(.callout)
                        }
                        if event.attendeeCount > 0 {
                            Label("\(event.attendeeCount) attending", systemImage: "person.2").font(.callout)
                        }
                        if let creator = event.creatorKadi {
                            Label("by @\(creator)", systemImage: "person").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)

                if let desc = event.description, !desc.isEmpty {
                    Text(desc).font(.body).lineSpacing(4).textSelection(.enabled)
                        .padding(.horizontal, 24)
                }

                Divider().padding(.horizontal, 24)

                HStack(spacing: 12) {
                    if event.myResponse == "attend" {
                        Button { onRespond("attend") } label: {
                            Label("Attend", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("You are attending")
                    } else {
                        Button { onRespond("attend") } label: {
                            Label("Attend", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .help("RSVP to attend")
                    }

                    if event.myResponse == "decline" {
                        Button { onRespond("decline") } label: {
                            Label("Decline", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary)
                        .help("You declined")
                    } else {
                        Button { onRespond("decline") } label: {
                            Label("Decline", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .help("Decline this event")
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 24)
            }
        }
    }
}
