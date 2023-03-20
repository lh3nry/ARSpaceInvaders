//
//  SheetSettingsView.swift
//  ARGame
//
//  Created by Henry Li on 2023-03-18.
//

import SwiftUI

struct SheetSettingsView: View {
    @Binding var invaderMaxSpeed: Float
    @Binding var invaderRows: Int
    @Binding var gameResarted: Bool
    
    @State var settingsChanged: Bool = false
    
    var body: some View {

        NavigationView() {
            Form {
                VStack(alignment: .leading) {
                    Text("Invader Max Speed")
                    Slider(value: $invaderMaxSpeed, in: 0.06...0.2) {
                        Text("Invader Max Speed")
                    }
                    .padding()
                }
                VStack(alignment: .leading) {
                    Text("Number of Invader Rows")
                    Picker(selection: $invaderRows, label: Label("Number of Invader Rows", systemImage: "line.3.horizontal")) {
                        ForEach(3...10, id: \.self) { i in
                            Text("\(i)")
                        }
                    }
                    .labelStyle(.titleOnly)
                    .pickerStyle(.segmented)
                    .padding()
                    
                }
                Button("Restart") {
                    NotificationCenter.default.post(Notification(name: .restartGameEvent))
                    gameResarted = true
                    settingsChanged = false
                }
                .foregroundColor(settingsChanged ? .red : .blue)
            }
            .navigationTitle(Text("Settings"))
            .onChange(of: invaderRows) { _ in
                settingsChanged = true
            }
            .onChange(of: invaderMaxSpeed) { _ in
                settingsChanged = true
            }
        }
        
    }
}

//struct SettingsView: View {
//
//    var body: some View {
//
//    }
//}

struct SheetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SheetSettingsView(
            invaderMaxSpeed: .constant(0.1),
            invaderRows: .constant(5),
            gameResarted: .constant(false))
    }
}
