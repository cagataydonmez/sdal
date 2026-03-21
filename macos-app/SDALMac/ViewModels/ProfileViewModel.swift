import Foundation

@MainActor
@Observable
final class ProfileViewModel {
    var profile: User?
    var isLoading = false
    var isSaving = false
    var error: String?
    var successMessage: String?

    var firstName = ""
    var lastName = ""
    var city = ""
    var company = ""
    var title = ""
    var expertise = ""
    var university = ""
    var department = ""
    var linkedinUrl = ""
    var profession = ""
    var website = ""
    var signature = ""
    var mentorOptIn = false
    var mentorTopics = ""
    var hideEmail = false
    var birthDay = 0
    var birthMonth = 0
    var birthYear = 0

    func loadProfile() async {
        isLoading = true
        error = nil
        do {
            let response: ProfileResponse = try await APIClient.shared.get("/api/profile")
            profile = response.user
            if let user = response.user {
                populateFields(from: user)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func populateFields(from user: User) {
        firstName = user.isim ?? ""
        lastName = user.soyisim ?? ""
        city = user.sehir ?? ""
        company = user.sirket ?? ""
        title = user.unvan ?? ""
        expertise = user.uzmanlik ?? ""
        university = user.universite ?? ""
        department = user.universiteBolum ?? ""
        linkedinUrl = user.linkedinUrl ?? ""
        profession = user.meslek ?? ""
        website = user.websitesi ?? ""
        signature = user.imza ?? ""
        mentorOptIn = user.mentorOptIn?.boolValue ?? false
        mentorTopics = user.mentorKonulari ?? ""
        hideEmail = user.mailkapali?.boolValue ?? false
        birthDay = user.dogumgun ?? 0
        birthMonth = user.dogumay ?? 0
        birthYear = user.dogumyil ?? 0
    }

    func saveProfile() async {
        isSaving = true
        error = nil
        successMessage = nil

        do {
            let body = ProfileUpdateRequest(
                isim: firstName, soyisim: lastName, sehir: city,
                meslek: profession, websitesi: website, universite: university,
                sirket: company, unvan: title, uzmanlik: expertise,
                linkedin_url: linkedinUrl, universite_bolum: department,
                mentor_opt_in: mentorOptIn, mentor_konulari: mentorTopics,
                imza: signature, mailkapali: hideEmail ? 1 : 0,
                dogumgun: birthDay, dogumay: birthMonth, dogumyil: birthYear
            )
            let _: ProfileUpdateResponse = try await APIClient.shared.put("/api/profile", body: body)
            successMessage = "Profile updated successfully"
            await AuthService.shared.refresh()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
