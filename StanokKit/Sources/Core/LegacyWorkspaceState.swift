import Foundation

struct LegacyWorkspaceState: Decodable {

    private enum CodingKeys: String, CodingKey {

        case lastSessionID
        case selectedFile
        case panelMode
        case expandedFolderPaths
        case scrollAnchorPath
    }

    let lastSessionID: UUID?

    let selectedFile: String?

    let panelMode: String?

    let expandedFolderPaths: [String]?

    let scrollAnchorPath: String?

    init(
        lastSessionID: UUID? = nil,
        selectedFile: String? = nil,
        panelMode: String? = nil,
        expandedFolderPaths: [String]? = nil,
        scrollAnchorPath: String? = nil
    ) {
        self.lastSessionID = lastSessionID
        self.selectedFile = selectedFile
        self.panelMode = panelMode
        self.expandedFolderPaths = expandedFolderPaths
        self.scrollAnchorPath = scrollAnchorPath
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.lastSessionID = try container.decodeIfPresent(UUID.self, forKey: .lastSessionID)
        self.selectedFile = try container.decodeIfPresent(String.self, forKey: .selectedFile)
        self.panelMode = try container.decodeIfPresent(String.self, forKey: .panelMode)
        self.expandedFolderPaths = try container.decodeIfPresent(
            [String].self,
            forKey: .expandedFolderPaths
        )
        self.scrollAnchorPath = try container.decodeIfPresent(
            String.self,
            forKey: .scrollAnchorPath
        )
    }
}
