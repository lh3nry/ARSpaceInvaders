//
//  ContentView.swift
//  ARGame
//
//  Created by Henry Li on 2023-03-13.
//

import SwiftUI
import RealityKit

extension Notification.Name {
    static let weaponFiredEvent = Notification.Name("WeaponFiredEvent")
}

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewPort()
            
            Button(action: {
                NotificationCenter.default.post(Notification(name: .weaponFiredEvent))
            }) {
                Text("PewPew")
                    .fontWeight(.heavy)
                    .frame(width: 130, height: 130)
                    .foregroundColor(Color.white)
                    .background(Color.red)
                    .clipShape(Circle())
            }

            Spacer()
        }
    }
}

struct ARViewPort: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = SpatialView(frame: .zero)
        arView.setup()
        
//        arView.debugOptions.insert(.showPhysics)
        
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
