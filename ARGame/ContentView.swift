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
    @State var showUIPanel = true
    @State var panelDetent = PresentationDetent.height(200)
    @State var invaderMaxSpeed: Float = 0.2
    @State var invaderRows: Int = 5
    
    @State var gameLost: Bool = false
    @State var gamePaused: Bool = false
    
    let customDetent = PresentationDetent.height(200)
    
    var body: some View {
        ZStack(alignment: .top) {
            ARViewPort(
                parentView: self,
                invaderMaxSpeed: $invaderMaxSpeed,
                numberOfInvaderRows: $invaderRows,
                gamePaused: $gamePaused)
            .sheet(isPresented: $showUIPanel) {
                    Button(action: {
                        NotificationCenter.default.post(Notification(name: .weaponFiredEvent))
                    }) {
                        if !gamePaused {
                            Text("PewPew")
                                .fontWeight(.heavy)
                                .frame(width: 130, height: 130)
                                .foregroundColor(Color.white)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top)
                SheetSettingsView(invaderMaxSpeed: $invaderMaxSpeed, invaderRows: $invaderRows)
                .presentationDetents([.medium, customDetent], selection: $panelDetent)
                .onDisappear() { showUIPanel = true }
                .onChange(of: panelDetent) {newValue in
                    if newValue == .medium {
                        print("Settings panel visible")
                        withAnimation {
                            gamePaused = true
                        }
                    }
                    else if newValue == customDetent {
                        if gameLost {
                            panelDetent = .medium
                            return
                        }
                        print("Settings panel slid down")
                        withAnimation {
                            gamePaused = false
                        }
                    }
                }
            }
        }
    }
    
    func arGameLost() {
        if gameLost { return }
        print("Detected game loss from child view")
        panelDetent = .medium
        gameLost = true
    }
}

struct ARViewPort: UIViewRepresentable {
    let parentView: any View
    @Binding var invaderMaxSpeed: Float
    @Binding var numberOfInvaderRows: Int
    @Binding var gamePaused: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = SpatialView(frame: .zero)
        arView.setup(parentView: parentView)
        
//        arView.debugOptions.insert(.showPhysics)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update bindings and state here
        if let spatialView = uiView as? SpatialView {
            Utilities.maxSpeed = self.invaderMaxSpeed
            Utilities.numRows = self.numberOfInvaderRows
            
            spatialView.setInvader(shouldMove: !gamePaused)
        }
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
