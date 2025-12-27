//
//  TestView.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/27.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color(.systemTeal).opacity(0.3)
                .ignoresSafeArea()

            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    TestView()
}
