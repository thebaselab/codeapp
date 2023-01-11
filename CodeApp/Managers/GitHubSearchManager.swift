//
//  GitHubSearchManager.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

class GitHubSearchManager: ObservableObject {

    @Published var searchResultItems: [item] = []
    @Published var templates: [item]? = nil
    @Published var searchTerm: String = ""
    @Published var errorMessage: String = ""

    static let endpoint = "https://api.github.com/search/repositories"

    struct searchResult: Decodable {
        let items: [item]
    }

    struct item: Decodable {
        let name: String
        let html_url: String
        let clone_url: String
        let description: String?
        let stargazers_count: Int
        let size: Int
        let language: String?
        let owner: owner
    }

    struct owner: Decodable {
        let login: String
        let avatar_url: String
    }

    func search() {
        if searchTerm == "" {
            return
        }
        self.errorMessage = ""

        let query = searchTerm + "&per_page=10"

        Task {
            let items = try await executeQuery(query: query)
            await MainActor.run {
                self.searchResultItems = items
            }
        }
    }

    func listTemplates() {
        let query = "topic:codeapp-template sort:stars"
        Task {
            let templates = try await executeQuery(query: query)
            await MainActor.run {
                self.templates = templates
            }
        }
    }

    private func executeQuery(query: String) async throws -> [item] {
        guard let query = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return []
        }
        let url = URL(string: GitHubSearchManager.endpoint + "?q=\(query)")!
        print(url.absoluteString)
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(searchResult.self, from: data)
        return result.items
    }
}
