import Testing
@testable import GitHubExplorer

@Suite("GroupingOption")
@MainActor struct GroupingOptionTests {

    @Test("All cases provide a system image name")
    func allCasesHaveSystemImage() {
        for option in GroupingOption.allCases {
            #expect(!option.systemImage.isEmpty)
        }
    }

    @Test("All cases provide a non-empty raw value")
    func allCasesHaveRawValue() {
        for option in GroupingOption.allCases {
            #expect(!option.rawValue.isEmpty)
        }
    }

    @Test("id matches rawValue")
    func idMatchesRawValue() {
        for option in GroupingOption.allCases {
            #expect(option.id == option.rawValue)
        }
    }
}
