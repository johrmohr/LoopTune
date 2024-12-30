//
//  ContentView.swift
//  LoopTune
//
//  Created by Jordan Moreno on 12/21/24.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            CustomTabView(selectedTab: $selectedTab)
            
            TabView(selection: $selectedTab) {
                LoopView()
                    .tag(0)
                TuneView()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
