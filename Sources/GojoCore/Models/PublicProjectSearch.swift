import Foundation

public enum PublicProjectSearch {
    public static func filter(_ projects: [PublicProject], query: String) -> [PublicProject] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return projects }
        return projects.filter {
            $0.name.localizedStandardContains(needle)
                || $0.url.localizedStandardContains(needle)
        }
    }
}
