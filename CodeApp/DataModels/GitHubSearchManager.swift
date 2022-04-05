//
//  GitHubSearchManager.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

class GitHubSearchManager: ObservableObject {

    @Published var searchResultItems: [item] = []
    @Published var searchTerm: String = ""
    @Published var errorMessage: String = ""

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
        var request = URLRequest(
            url: URL(
                string:
                    "https://api.github.com/search/repositories?q=\(searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&per_page=10"
            )!)
        request.httpMethod = "GET"

        let session = URLSession.shared
        session.dataTask(with: request) { data, response, err in
            if data != nil {
                DispatchQueue.main.async {
                    do {
                        let result = try JSONDecoder().decode(searchResult.self, from: data!)
                        self.searchResultItems = result.items
                    } catch {
                        print("search error: \(error)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Could not connect to GitHub's server."
                }
            }
        }.resume()
    }
}
