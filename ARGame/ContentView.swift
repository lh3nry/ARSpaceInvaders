//
//  ContentView.swift
//  ARGame
//
//  Created by Henry Li on 2023-03-13.
//

import SwiftUI
import RealityKit
import Combine

extension Notification.Name {
    static let weaponFiredEvent = Notification.Name("WeaponFiredEvent")
    static let restartGameEvent = Notification.Name("RestartGameEvent")
}

struct ContentView: View {
    @State var showUIPanel = true
    @State var panelDetent = PresentationDetent.height(200)
    @State var invaderMaxSpeed: Float = 0.2
    @State var invaderRows: Int = 5
    @State var gameStatus: String?
    
    @State var gameLost: Bool = false
    @State var gamePaused: Bool = false
    @State var gameReset: Bool = false
    @State var gameWon: Bool = false
    
    let gameWinStatus = "CLEARED"
    let gamePausedStatus = "GAME PAUSED"
    let gameLostStatus = "GAME OVER"
    
    let customDetent = PresentationDetent.height(200)
    
//    var modelLoadTask: Cancellable!
    let models: [ModelEntity] = {
        let fileManager = FileManager.default
        
        guard let path = Bundle.main.resourcePath, let files = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }
        
        var availableModels: [ModelEntity] = []
        if let player = files.first(where: { filename in
            filename.contains("player")
        }) {
            if let unwrapped = try? ModelEntity.loadModel(named: player) {
                availableModels.append(unwrapped)
            }
        }
        for filename in files where filename.contains("invader") {
            let model = try? ModelEntity.loadModel(named: filename)
            if let unwrapped = model {
                availableModels.append(unwrapped)
            }
        }
//        for filename in files where filename.hasSuffix("usdz") {
//            let model = try? ModelEntity.loadModel(named: filename)
//            if let unwrapped = model {
//                availableModels.append(unwrapped)
//            }
////            ModelEntity.loadModelAsync(named: filename)
////                .sink(
////                    receiveCompletion: { loadCompletion in
////                        print("DEBUG: Unable to load modelEntity for filename: \(filename)")},
////                    receiveValue: { modelEntity in
////                        availableModels.append(modelEntity)
////                        print("DEBUG: Successfully loaded ModelEntity for file: \(filename)")
////                    })
//        }
        
        return availableModels
    }()
    
    var body: some View {
        ZStack(alignment: .top) {
            ARViewPort(
                parentView: self,
                models: models,
                invaderMaxSpeed: $invaderMaxSpeed,
                numberOfInvaderRows: $invaderRows,
                gamePaused: $gamePaused)
            .overlay(
                Text(gameStatus ?? "")
                    .foregroundColor(.white)
                    .fontWeight(.heavy)
                    .shadow(color: .gray, radius: 3)
                    .font(.system(size: 54))
                    .padding(),
                alignment: .top)
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
                SheetSettingsView(invaderMaxSpeed: $invaderMaxSpeed, invaderRows: $invaderRows, gameResarted: $gameReset)
                .presentationDetents([.medium, customDetent], selection: $panelDetent)
                .onDisappear() {
                    showUIPanel = true
                    if panelDetent == .medium {
                        gamePaused = false
                        selectedPanelDetent(changedTo: customDetent)
                    }
                }
                .onChange(of: panelDetent) { newValue in
                    selectedPanelDetent(changedTo: newValue)
                    if newValue == .medium {
                        withAnimation {
                            gamePaused = true
                        }
                    }
                    else if newValue == customDetent {
                        withAnimation {
                            gamePaused = false
                        }
                    }
                }
            }
            .onChange(of: gameReset) { newValue in
                if newValue == true {
                    gameReset = false
                    gameLost = false
                    gameWon = false
                    gameStatus = gamePausedStatus
                }
            }
        }
    }
    
    func selectedPanelDetent(changedTo newValue: PresentationDetent) {
        if panelDetent != newValue { panelDetent = newValue }
        
        if newValue == .medium {
            gameStatus = gameLost ? gameLostStatus : gamePausedStatus
        }
        else if newValue == customDetent {
            if gameLost {
                panelDetent = .medium
                gamePaused = true
                return
            }
            gameStatus = ""
        }
    }
    
    func arGameLost() {
        if gameLost { return }
        print("Detected game loss from child view")
        panelDetent = .medium
        gameLost = true
    }
    
    func onGameWon() {
        gameWon = true
        gameStatus = gameWinStatus
    }
}

struct ARViewPort: UIViewRepresentable {
    let parentView: any View
    let models: [ModelEntity]
    @Binding var invaderMaxSpeed: Float
    @Binding var numberOfInvaderRows: Int
    @Binding var gamePaused: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = SpatialView(frame: .zero)
        arView.setup(parentView: parentView, models: models)
        
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
