import Foundation

@MainActor
@Observable
final class JobsViewModel {
    var jobs: [Job] = []
    var selectedJob: Job?
    var isLoading = false
    var error: String?
    var searchQuery = ""
    var hasMore = true
    private var offset = 0
    private var searchTask: Task<Void, Never>?

    func loadJobs(reset: Bool = false) async {
        if reset { offset = 0; hasMore = true }
        guard hasMore || reset else { return }
        isLoading = true
        error = nil

        do {
            var query = ["offset": "\(offset)", "limit": "40"]
            if !searchQuery.isEmpty { query["search"] = searchQuery }
            let response: JobsResponse = try await APIClient.shared.get("/api/new/jobs", query: query)
            let newJobs = response.items ?? []
            if reset {
                jobs = newJobs
            } else {
                jobs.append(contentsOf: newJobs)
            }
            hasMore = response.hasMore ?? !newJobs.isEmpty
            offset += newJobs.count
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func search(_ query: String) {
        searchQuery = query
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await loadJobs(reset: true)
        }
    }

    func applyToJob(_ jobId: Int, message: String) async {
        do {
            struct ApplyBody: Encodable { let message: String }
            try await APIClient.shared.postVoid("/api/new/jobs/\(jobId)/apply", body: ApplyBody(message: message))
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createJob(title: String, company: String, description: String, location: String, jobType: String) async {
        do {
            struct CreateJob: Encodable {
                let title: String
                let company: String
                let description: String
                let location: String
                let job_type: String
            }
            try await APIClient.shared.postVoid("/api/new/jobs", body: CreateJob(
                title: title, company: company, description: description,
                location: location, job_type: jobType
            ))
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await loadJobs(reset: true)
    }
}
