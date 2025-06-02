//
//  ContentView.swift
//  2B
//
//  Created by Nir Portiansky on 29/05/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Second Brain")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Press ⌘⇧Space to search your memories")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}
