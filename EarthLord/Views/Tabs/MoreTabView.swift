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
                        SupabaseTestView()
                    } label: {
                        Label("Supabase 连接测试", systemImage: "network")
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
