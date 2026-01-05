//
//  MoreTabView.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/27.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("开发者工具") {
                    NavigationLink {
                        TestMenuView()
                    } label: {
                        Label("开发测试", systemImage: "hammer.fill")
                    }
                }
            }
            .navigationTitle("更多")
            .scrollContentBackground(.hidden)
            .background(ApocalypseTheme.background)
        }
    }
}

#Preview {
    MoreTabView()
}
