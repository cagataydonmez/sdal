import SwiftUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        Form {
            if viewModel.isLoading {
                Section { LoadingView(message: "Loading profile...") }
            } else {
                if let error = viewModel.error {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(error)
                        }
                    }
                }

                if let msg = viewModel.successMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(msg)
                        }
                    }
                }

                Section("Personal") {
                    TextField("First Name", text: $viewModel.firstName)
                    TextField("Last Name", text: $viewModel.lastName)
                    TextField("City", text: $viewModel.city)
                }

                Section("Professional") {
                    TextField("Company", text: $viewModel.company)
                    TextField("Title", text: $viewModel.title)
                    TextField("Expertise", text: $viewModel.expertise)
                    TextField("Profession", text: $viewModel.profession)
                    TextField("LinkedIn URL", text: $viewModel.linkedinUrl)
                }

                Section("Education") {
                    TextField("University", text: $viewModel.university)
                    TextField("Department", text: $viewModel.department)
                    TextField("Website", text: $viewModel.website)
                }

                Section("Mentorship") {
                    Toggle("Available as Mentor", isOn: $viewModel.mentorOptIn)
                    if viewModel.mentorOptIn {
                        TextField("Mentor Topics", text: $viewModel.mentorTopics)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.saveProfile() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Save", systemImage: "checkmark")
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(viewModel.isSaving)
                .help("Save profile changes")
            }
        }
        .task { await viewModel.loadProfile() }
    }
}
