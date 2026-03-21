import SwiftUI

struct JobsView: View {
    @State private var viewModel = JobsViewModel()
    @State private var showCreateJob = false
    @State private var showApplySheet = false
    @State private var applyMessage = ""

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search jobs", text: Binding(
                        get: { viewModel.searchQuery },
                        set: { viewModel.search($0) }
                    ))
                    .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(10)

                Divider()

                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    LoadingView(message: "Loading jobs...")
                } else if viewModel.jobs.isEmpty {
                    EmptyStateView(icon: "briefcase", title: "No jobs posted", message: "Job listings will appear here.")
                } else {
                    List(viewModel.jobs, selection: $viewModel.selectedJob) { job in
                        JobRowView(job: job).tag(job)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)

            if let job = viewModel.selectedJob {
                JobDetailPanel(job: job) {
                    showApplySheet = true
                }
            } else {
                EmptyStateView(icon: "briefcase", title: "Select a job", message: "Choose a job listing to view details.")
            }
        }
        .navigationTitle("Jobs")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showCreateJob = true } label: {
                    Label("Post Job", systemImage: "plus")
                }
                .help("Post a new job listing")

                Button { Task { await viewModel.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh job listings")
            }
        }
        .sheet(isPresented: $showCreateJob) {
            CreateJobSheet { title, company, desc, location, jobType in
                Task { await viewModel.createJob(title: title, company: company, description: desc, location: location, jobType: jobType) }
            }
        }
        .sheet(isPresented: $showApplySheet) {
            ApplyJobSheet(jobTitle: viewModel.selectedJob?.title ?? "") { message in
                if let jobId = viewModel.selectedJob?.id {
                    Task { await viewModel.applyToJob(jobId, message: message) }
                }
            }
        }
        .task { await viewModel.loadJobs(reset: true) }
    }
}

struct JobRowView: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(job.title ?? "Job").font(.callout).fontWeight(.medium).lineLimit(2)
            HStack(spacing: 4) {
                if let company = job.company, !company.isEmpty {
                    Text(company).font(.caption).foregroundStyle(.secondary)
                }
                if let location = job.location, !location.isEmpty {
                    Text("· \(location)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            HStack(spacing: 6) {
                if !job.jobTypeLabel.isEmpty {
                    Text(job.jobTypeLabel).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                if job.hasApplied {
                    Text("Applied").font(.caption2).foregroundStyle(.green)
                }
                Spacer()
                Text(job.relativeTime).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct JobDetailPanel: View {
    let job: Job
    var onApply: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.title ?? "Job").font(.title2).fontWeight(.bold)
                    HStack(spacing: 12) {
                        if let company = job.company { Label(company, systemImage: "building.2").font(.callout) }
                        if let location = job.location { Label(location, systemImage: "mappin").font(.callout) }
                    }
                    HStack(spacing: 12) {
                        if !job.jobTypeLabel.isEmpty { Label(job.jobTypeLabel, systemImage: "clock").font(.callout) }
                        if let salary = job.salaryRange { Label(salary, systemImage: "banknote").font(.callout) }
                    }
                    .foregroundStyle(.secondary)

                    Text("Posted by \(job.posterDisplayName) · \(job.relativeTime)")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 24).padding(.top, 20)

                Divider().padding(.horizontal, 24)

                if let desc = job.description, !desc.isEmpty {
                    Text(HTMLHelper.strip(desc)).font(.body).lineSpacing(4).textSelection(.enabled)
                        .padding(.horizontal, 24)
                }

                if !job.hasApplied {
                    Button { onApply() } label: {
                        Label("Apply Now", systemImage: "paperplane")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                    .help("Apply to this job")
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("You have applied").font(.callout)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 24)
            }
        }
    }
}

struct CreateJobSheet: View {
    var onSubmit: (String, String, String, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var company = ""
    @State private var description = ""
    @State private var location = ""
    @State private var jobType = "full_time"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Text("Post a Job").font(.headline)
                Spacer()
                Button("Post") {
                    onSubmit(title, company, description, location, jobType)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || company.isEmpty)
            }
            .padding()
            Divider()

            Form {
                TextField("Job Title", text: $title)
                TextField("Company", text: $company)
                TextField("Location", text: $location)
                Picker("Type", selection: $jobType) {
                    Text("Full-time").tag("full_time")
                    Text("Part-time").tag("part_time")
                    Text("Contract").tag("contract")
                    Text("Internship").tag("internship")
                    Text("Freelance").tag("freelance")
                }
                TextEditor(text: $description).frame(minHeight: 100)
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 420)
    }
}

struct ApplyJobSheet: View {
    let jobTitle: String
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Text("Apply").font(.headline)
                Spacer()
                Button("Submit") {
                    onSubmit(message)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Applying to: \(jobTitle)").font(.callout).foregroundStyle(.secondary)
                Text("Cover message:").font(.callout).fontWeight(.medium)
                TextEditor(text: $message).frame(minHeight: 120)
            }
            .padding()
        }
        .frame(width: 440, height: 320)
    }
}
