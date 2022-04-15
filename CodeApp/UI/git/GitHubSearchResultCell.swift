//
//  GitHubResultCell.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct GitHubSearchResultCell: View {

    @State var item: GitHubSearchManager.item

    func humanReadableByteCount(bytes: Int) -> String {
        if bytes < 1000 { return "\(bytes) B" }
        let exp = Int(log2(Double(bytes)) / log2(1000.0))
        let unit = ["KB", "MB", "GB", "TB", "PB", "EB"][exp - 1]
        let number = Double(bytes) / pow(1000, Double(exp))
        return String(format: "%.1f %@", number, unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                RemoteImage(url: item.owner.avatar_url)
                    .frame(width: 20, height: 20)
                    .cornerRadius(5)
                Text(item.owner.login)
                    .font(.system(size: 12))
                    .foregroundColor(Color.init("T1"))
            }

            Text(item.name)
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(Color.init("T1"))

            if item.description != nil {
                Text(item.description!)
                    .font(.system(size: 14))
                    .foregroundColor(Color.init("T1"))
            }

            HStack {
                Image(systemName: "star")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                DescriptionText("\(item.stargazers_count)")

                if item.language != nil {
                    DescriptionText(
                        "\(item.language ?? "")  • \(humanReadableByteCount(bytes: item.size*1024))"
                    )
                } else {
                    DescriptionText("\(humanReadableByteCount(bytes: item.size*1024))")
                }

                Spacer()

                CloneButton(item: item)
            }
        }
    }
}
