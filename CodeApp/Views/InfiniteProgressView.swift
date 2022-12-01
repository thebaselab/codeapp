//
//  InfiniteProgressView.swift
//  Code
//
//  Created by Ken Chung on 10/4/2022.
//

import SwiftUI

struct InfinityProgressView: View {

    @State private var atLeading: Bool = false
    let enabled: Bool

    private var repeatingAnimation: Animation {
        Animation
            .easeInOut(duration: 1)
            .repeatForever()
    }

    var body: some View {
        GeometryReader { geometry in
            if enabled {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.blue)
                    .frame(maxWidth: 30, maxHeight: 3)
                    .offset(x: atLeading ? geometry.size.width - 30 : 0, y: 0)
                    .onAppear {
                        withAnimation(repeatingAnimation) {
                            atLeading.toggle()
                        }
                    }
            }
        }
        .frame(height: 8)
    }
}
