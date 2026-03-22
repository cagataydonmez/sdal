import SwiftUI

@main
struct SDALMacApp: App {
    private let auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if auth.isLoading {
                    launchScreen
                } else if auth.isAuthenticated {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .task { await auth.checkSession() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Post") {
                    NotificationCenter.default.post(name: .newPost, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("New Message") {
                    NotificationCenter.default.post(name: .newMessage, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Feed") {
                    NotificationCenter.default.post(name: .navigate, object: SidebarItem.feed)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Messages") {
                    NotificationCenter.default.post(name: .navigate, object: SidebarItem.messages)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Members") {
                    NotificationCenter.default.post(name: .navigate, object: SidebarItem.members)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Groups") {
                    NotificationCenter.default.post(name: .navigate, object: SidebarItem.groups)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Events") {
                    NotificationCenter.default.post(name: .navigate, object: SidebarItem.events)
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Stories") {
                    NotificationCenter.default.post(name: .navigate, object: SidebarItem.stories)
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Jobs") {
                    NotificationCenter.default.post(name: .navigate, object: SidebarItem.jobs)
                }
                .keyboardShortcut("7", modifiers: .command)

                Button("Notifications") {
                    NotificationCenter.default.post(name: .navigate, object: SidebarItem.notifications)
                }
                .keyboardShortcut("8", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("SDAL Help") {
                    // Open help
                }
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }

    private var launchScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("SDAL")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("showNotificationBadge") private var showBadge = true

    var body: some View {
        Form {
            Section("General") {
                Picker("Auto-refresh interval", selection: $refreshInterval) {
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                    Text("Off").tag(0)
                }
                Toggle("Show notification badge", isOn: $showBadge)
            }

            Section("Connection") {
                LabeledContent("Server") {
                    Text(APIConfig.baseURL).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 200)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newPost = Notification.Name("com.sdal.newPost")
    static let newMessage = Notification.Name("com.sdal.newMessage")
    static let navigate = Notification.Name("com.sdal.navigate")
}
