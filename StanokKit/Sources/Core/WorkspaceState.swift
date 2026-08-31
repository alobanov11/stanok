import Foundation

public struct WorkspaceState: Codable, Equatable, Sendable {

    private enum CodingKeys: String, CodingKey {

        case selectedFile
        case panelMode
        case expandedFolderPaths
        case scrollAnchorPath
    }

    public var selectedFile: String?
    public var panelMode: String?
    public var expandedFolderPaths: [String]?
    public var scrollAnchorPath: String?

    public init(
        selectedFile: String? = nil,
        panelMode: String? = nil,
        expandedFolderPaths: [String]? = nil,
        scrollAnchorPath: String? = nil
    ) {
        self.selectedFile = selectedFile
        self.panelMode = panelMode
        self.expandedFolderPaths = expandedFolderPaths
        self.scrollAnchorPath = scrollAnchorPath
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
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
