//
//  SheetTester.swift
//  ARGame
//
//  Created by Henry Li on 2023-03-18.
//

import SwiftUI

struct SheetTester: View {
    @State var showUIPanel = true
    @State var panelDetent = PresentationDetent.height(200)
    @State var invaderMaxSpeed: Float = 0.01
    @State var invaderRows: Int = 5
    
    @State var gamePaused: Bool = false

    let customDetent = PresentationDetent.height(200)
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
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
//                        else {
//                            Text("PewPew")
//                                .fontWeight(.heavy)
//                                .frame(width: 130, height: 50)
//                                .foregroundColor(Color.white)
//                                .background(Color.red)
//                                .clipShape(Capsule(style: .continuous))
//                        }
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
                        print("Settings panel slid down")
                        withAnimation {
                            gamePaused = false
                        }
                    }
                }
            }
    }
}

struct SheetTester_Previews: PreviewProvider {
    static var previews: some View {
        SheetTester()
    }
}
