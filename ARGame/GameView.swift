//
//  GameView.swift
//  ARGame
//
//  Created by Henry Li on 2023-03-13.
//

import Foundation
import SwiftUI
import ARKit
import RealityKit
import Combine

class ChangeMeshAndColorSystem: System {
    static let query = EntityQuery(where: .has(ModelComponent.self) && .has(InvaderComponent.self))
    
    required init(scene: RealityKit.Scene) {
        print("System is activated!")
    }
    
    let moves: [(x: Float, y: Float)] = [(1,0), (0,-1), (-1,0), (0,-1)]
    let stateCount = 4
    
    func update(context: SceneUpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            guard let model = entity as? ModelEntity else { return }
            
            guard let invader = model.components[InvaderComponent.self] as? InvaderComponent else { return }
        
            let xlimit = invader.limits[invader.moveState].x
            
            if invader.moveState == 0 && xlimit > 0 && model.position.x > xlimit{
//                print("branch 1")
                model.position.x = xlimit - Float(context.deltaTime)
                invader.moveState = (invader.moveState + 1) % stateCount
//                model.model?.mesh = getTextMesh(for: "\(invader.moveState)")
            }
            else if invader.moveState == 2 && xlimit < 0 && model.position.x < xlimit {
//                print("branch 2")

                model.position.x = xlimit + Float(context.deltaTime)
                invader.moveState = (invader.moveState + 1) % stateCount
//                model.model?.mesh = getTextMesh(for: "\(invader.moveState)")
            }
            else if (invader.moveState == 1 || invader.moveState == 3) && model.position.y < invader.limits[invader.moveState].y {
//                print("branch 3")
//                print("\(invader.moveState) \(invader.limits[invader.moveState]) pos (\(model.position.x), \(model.position.y)), move (\(moves[invader.moveState]) ")
//                model.position.y -= Float(context.deltaTime) * moves[invader.moveState].y
                invader.moveState = (invader.moveState + 1) % stateCount
//                model.model?.mesh = getTextMesh(for: "\(invader.moveState)")

                invader.limits[1].y -= 0.25
                invader.limits[3].y -= 0.25
            }
            else {
//                print("branch 4")

                model.position.x += Float(context.deltaTime) * moves[invader.moveState].x
                model.position.y += Float(context.deltaTime) * moves[invader.moveState].y
            }
            

            
//
//            model.model?.mesh = getTextMesh(for: "\(invader.moveState)")
//
//            var material = PhysicallyBasedMaterial()
//            material.baseColor.tint = .systemOrange
//
//            entity.model?.materials = [material]
        }
    }
    
    func getTextMesh(for string: String) -> MeshResource {
        return MeshResource.generateText(
                              string,
              extrusionDepth: 0.01,
                        font: .systemFont(ofSize: 0.15),
              containerFrame: .zero,
                   alignment: .center,
               lineBreakMode: .byCharWrapping)
    }
}

class InvaderComponent: Component {
    var limits : [(x: Float, y: Float)]
    var moveState = 0
    
    init(limits: [(x: Float, y: Float)]) {
        self.limits = limits
    }
//
//    func updateLimits(at index: Int, x: Float, y: Float) {
//        self.limits[index] = (x, y)
//    }
}

class SpatialView: ARView {
    var updateSub: Cancellable!
    var cubeEntity, entity: ModelEntity?
    
    required init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        isMultipleTouchEnabled = true
    }

    override var canBecomeFirstResponder: Bool { true }

    func setup() {
        registerComponents()
//        doCubeSetup()
        
        doECSTestSetup()
    }
    
    func registerComponents() {
        InvaderComponent.registerComponent()
    }
    
    func doECSTestSetup() {
        ChangeMeshAndColorSystem.registerSystem()
        let anchor = AnchorEntity()
        
        let xspacing = Float(0.25)
        let yspacing = xspacing
        
        backgroundColor = .black
        
        for row in 1...3 {
            makeInvaderRow(onto: anchor, at: Float(row) * yspacing, withColumns: 5, withSpacing: xspacing)
        }
        scene.addAnchor(anchor)
    }
    
    func getTextMesh(for string: String) -> MeshResource {
        return MeshResource.generateText(
                              string,
              extrusionDepth: 0.01,
                        font: .systemFont(ofSize: 0.15),
              containerFrame: .zero,
                   alignment: .center,
               lineBreakMode: .byCharWrapping)
    }
    
    func makeInvaderRow(onto anchor: AnchorEntity, at y: Float, withColumns cols: Int, withSpacing spacing: Float) {
        let low = 1-(cols/2) - cols % 2
        let high = cols/2
        
        let starting = cols % 2 > 0 ? 0 : -(spacing/2)
        
        for index in low...high {
            let currNum = index + 3
            
            let text = getTextMesh(for: "\(currNum)")
 
            entity = ModelEntity(mesh: text,
                            materials: [UnlitMaterial()])
            entity?.position.x = starting + Float(index) * spacing
            entity?.position.y = y
            entity?.setParent(anchor)
            entity?.name = "Prim\(currNum)"
            
            
            entity?.components[InvaderComponent.self] =
                InvaderComponent(limits: generateLimits(
                    x: entity!.position.x,
                    y: y,
                    limitValue: 1))
            
            print(generateLimits(
                x: entity!.position.x,
                y: y,
                limitValue: 1))
            
            print("\(entity!.position.x), \(y)")
            

//            if currNum == 2 || currNum == 4 {
//                entity?.components[InvaderComponent.self] = .init()
//            }
        }
    }
    
    func generateLimits(x: Float, y: Float, limitValue: Float) -> [(Float, Float)] {
        return [(x+limitValue, 0), (x+limitValue, y-limitValue/4), (x-limitValue, 0), (x-limitValue, y-limitValue/4)]
    }
    
    func doCubeSetup() {
        updateSub = scene.subscribe(to: SceneEvents.Update.self) { [unowned self] in
            self.frameUpdate(on: $0)
        }
        
        let material = SimpleMaterial(color: .red, isMetallic: false)
        cubeEntity = ModelEntity(mesh: MeshResource.generateBox(size: 0.2, cornerRadius: 0.05), materials: [material])
        let initialAngle = simd_quatf(angle: Float(45.truncatingRemainder(dividingBy: .pi)), axis: SIMD3(1,0,1))
        cubeEntity?.transform.rotation = initialAngle
        let cubeAnchor = AnchorEntity()
        cubeAnchor.addChild(cubeEntity!)
        scene.addAnchor(cubeAnchor)
    }
    
    func frameUpdate(on event: SceneEvents.Update) {
        let angle = (event.deltaTime * 0.5).truncatingRemainder(dividingBy: .pi)
        
        let rotation = simd_quatf(angle: Float(angle), axis: SIMD3(1,0,0))
        
        cubeEntity?.transform.rotation *= rotation
    }
    
}
