//
//  ContentView.swift
//  Geo-Alarm
//
//  Created by winter.min on 8/3/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MapViewControllerRepresentable()
                    .ignoresSafeArea() // 화면 전체를 사용하도록 안전 영역을 무시합니다.
    }
}

#Preview {
    ContentView()
}
