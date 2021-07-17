//
//  GitHubAccountManager.swift
//  Code App
//
//  Created by Ken Chung on 2/1/2021.
//

import SwiftUI

class GitHubAccountManager: ObservableObject{
    
    @Published var searchResultItems: [item] = []
    
    struct item: Decodable{
        let name: String
        let `private`: Bool
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
    
    func search(){
        var request = URLRequest(url: URL(string: "https://api.github.com/user/repos")!)
        request.httpMethod = "GET"
        // Base64 of HTTP Basic Auth
        request.addValue("", forHTTPHeaderField: "Authorization")
        
        let session = URLSession.shared
        session.dataTask(with: request){data, response, err in
            if data != nil{
                DispatchQueue.main.async {
                    do{
                        let result = try JSONDecoder().decode([item].self, from: data!)
                        self.searchResultItems = result
                    }catch{
                        print("search error: \(error)")
                    }
                }
            }
        }.resume()
    }
}
