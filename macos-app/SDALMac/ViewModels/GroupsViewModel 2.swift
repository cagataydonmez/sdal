import Foundation

@MainActor
@Observable
final class GroupsViewModel {
    var groups: [SDALGroup] = []
    var selectedGroup: SDALGroup?
    var groupDetail: GroupDetailData?
    var isLoading = false
    var isLoadingDetail = false
    var error: String?

    func loadGroups() async {
        isLoading = true
        error = nil
        do {
            let response: GroupsResponse = try await APIClient.shared.get("/api/new/groups", query: ["limit": "100"])
            groups = response.items ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func selectGroup(_ group: SDALGroup) async {
        selectedGroup = group
        await loadGroupDetail(group.id)
    }

    func loadGroupDetail(_ groupId: Int) async {
        isLoadingDetail = true
        do {
            let response: GroupDetailResponse = try await APIClient.shared.get("/api/new/groups/\(groupId)")
            groupDetail = response.group
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingDetail = false
    }

    func joinGroup(_ groupId: Int) async {
        do {
            struct JoinBody: Encodable { let join_request: Bool }
            let _: GroupJoinResponse = try await APIClient.shared.post(
                "/api/new/groups/\(groupId)/join",
                body: JoinBody(join_request: true)
            )
            await loadGroups()
            if selectedGroup?.id == groupId {
                await loadGroupDetail(groupId)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await loadGroups()
    }
}
