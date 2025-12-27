//
//  ContentView.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/27.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            Text("Developed by [Feixiang]")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
