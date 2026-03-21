import SwiftUI

struct MemberDetailView: View {
    let member: User
    @State private var fullProfile: User?
    @State private var isLoading = false
    @State private var connectionSent = false

    private var profile: User { fullProfile ?? member }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    AvatarView(url: profile.photoURL, initials: profile.initials, size: 80, isOnline: profile.isOnline)
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text(profile.displayName).font(.title2).fontWeight(.semibold)
                            if profile.isVerified {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
                            }
                        }
                        if let kadi = profile.kadi {
                            Text("@\(kadi)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 24)

                VStack(spacing: 12) {
                    if let year = profile.mezuniyetyili, !year.isEmpty {
                        InfoRow(icon: "graduationcap", label: "Class of", value: year)
                    }
                    if let city = profile.sehir, !city.isEmpty {
                        InfoRow(icon: "mappin", label: "City", value: city)
                    }
                    if let company = profile.sirket, !company.isEmpty {
                        InfoRow(icon: "building.2", label: "Company", value: company)
                    }
                    if let title = profile.unvan, !title.isEmpty {
                        InfoRow(icon: "person.text.rectangle", label: "Title", value: title)
                    }
                    if let expertise = profile.uzmanlik, !expertise.isEmpty {
                        InfoRow(icon: "star", label: "Expertise", value: expertise)
                    }
                    if let uni = profile.universite, !uni.isEmpty {
                        InfoRow(icon: "building.columns", label: "University", value: uni)
                    }
                    if let dept = profile.universiteBolum, !dept.isEmpty {
                        InfoRow(icon: "book", label: "Department", value: dept)
                    }
                    if let linkedin = profile.linkedinUrl, !linkedin.isEmpty {
                        InfoRow(icon: "link", label: "LinkedIn", value: linkedin)
                    }
                    if let profession = profile.meslek, !profession.isEmpty {
                        InfoRow(icon: "briefcase", label: "Profession", value: profession)
                    }
                }
                .padding(.horizontal, 32)

                if profile.isMentor {
                    HStack(spacing: 8) {
                        Image(systemName: "graduationcap.fill").foregroundStyle(Color.accentColor)
                        Text("Available as Mentor").font(.callout).fontWeight(.medium)
                        if let topics = profile.mentorKonulari, !topics.isEmpty {
                            Text("· \(topics)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 32)
                }

                if profile.id != AuthService.shared.currentUser?.id {
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                try? await APIClient.shared.postVoid("/api/new/connections/request/\(profile.id)")
                                connectionSent = true
                            }
                        } label: {
                            Label(connectionSent ? "Request Sent" : "Connect", systemImage: connectionSent ? "checkmark" : "person.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(connectionSent)
                        .help("Send connection request")

                        Button { } label: {
                            Label("Message", systemImage: "message")
                        }
                        .buttonStyle(.bordered)
                        .help("Send a message")
                    }
                    .padding(.horizontal, 32)
                }

                Spacer(minLength: 24)
            }
        }
        .task(id: member.id) {
            connectionSent = false
            isLoading = true
            do {
                let response: MemberDetailResponse = try await APIClient.shared.get("/api/members/\(member.id)")
                fullProfile = response.row
            } catch { }
            isLoading = false
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(.secondary)
            Text(label).font(.callout).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(value).font(.callout).textSelection(.enabled)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
