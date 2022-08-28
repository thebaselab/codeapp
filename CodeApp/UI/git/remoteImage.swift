//
//  remoteImage.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct RemoteImage: View {
    private enum LoadState {
        case loading, success, failure
    }

    private class Loader: ObservableObject {
        var data = Data()
        var state = LoadState.loading

        init(url: String) {
            guard let parsedURL = URL(string: url) else {
                fatalError("Invalid URL: \(url)")
            }

            URLSession.shared.dataTask(with: parsedURL) { data, response, error in
                if let data = data, data.count > 0 {
                    self.data = data
                    self.state = .success
                } else {
                    self.state = .failure
                }

                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }.resume()
        }
    }

    @StateObject private var loader: Loader

    var body: some View {
        Group {
            switch loader.state {
            case .loading, .failure:
                Rectangle()
                    .fill(.clear)
            default:
                if let image = UIImage(data: loader.data) {
                    Image(uiImage: image).resizable()
                } else {
                    Rectangle()
                        .fill(.clear)
                }
            }
        }

    }

    init(
        url: String
    ) {
        _loader = StateObject(wrappedValue: Loader(url: url))
    }
}
