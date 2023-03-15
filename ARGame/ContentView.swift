//
//  ContentView.swift
//  ARGame
//
//  Created by Henry Li on 2023-03-13.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        ARViewPort()
    }
}

struct ARViewPort: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = SpatialView(frame: .zero)
        arView.setup()
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update bindings and state here
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
