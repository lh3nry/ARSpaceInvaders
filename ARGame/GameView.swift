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

class Utilities {
    static let spacing: Float = 0.02
    static let moveDistance: Float = 0.05
    static let moveDistanceVertical: Float = 0.025
    static let invaderSpeed: Float = 0.1
    
    static func getTextMesh(for string: String) -> MeshResource {
        return MeshResource.generateText(
                              string,
              extrusionDepth: 0.001,
                        font: .init(name: "Helvetica", size: 0.015)!,
              containerFrame: .zero,
                   alignment: .center,
               lineBreakMode: .byCharWrapping)
    }
}

class InvaderMotion: System {
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
            
            if !invader.doesMove { return }
        
            let xlimit = invader.limits[invader.moveState].x
            
            if invader.moveState == 0 && xlimit > 0 && model.position.x > xlimit{
                model.position.x = xlimit - Utilities.invaderSpeed * Float(context.deltaTime)
                invader.moveState = (invader.moveState + 1) % stateCount
                model.model?.mesh = Utilities.getTextMesh(for: "\(invader.moveState)")
            }
            else if invader.moveState == 2 && xlimit < 0 && model.position.x < xlimit {
                model.position.x = xlimit + Utilities.invaderSpeed * Float(context.deltaTime)
                invader.moveState = (invader.moveState + 1) % stateCount
                model.model?.mesh = Utilities.getTextMesh(for: "\(invader.moveState)")
            }
            else if (invader.moveState == 1 || invader.moveState == 3) && model.position.y < invader.limits[invader.moveState].y {
//                print("\(invader.moveState) \(invader.limits[invader.moveState]) pos (\(model.position.x), \(model.position.y)), move (\(moves[invader.moveState]) ")
//                model.position.y -= Float(context.deltaTime) * moves[invader.moveState].y
                invader.moveState = (invader.moveState + 1) % stateCount
                model.model?.mesh = Utilities.getTextMesh(for: "\(invader.moveState)")

                invader.limits[1].y -= Utilities.moveDistanceVertical
                invader.limits[3].y -= Utilities.moveDistanceVertical
            }
            else {
                model.position.x += Utilities.invaderSpeed * Float(context.deltaTime) * moves[invader.moveState].x
                model.position.y += Utilities.invaderSpeed * Float(context.deltaTime) * moves[invader.moveState].y
            }
        }
    }
}

class InvaderComponent: Component {
    var limits : [(x: Float, y: Float)]
    var moveState = 0
    var doesMove = false
    
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
    var boardScene: Gameboard.Scene?
    var gameAnchor: AnchorEntity?
    
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
        boardScene = try! Gameboard.loadScene()
//        scene.addAnchor(board)
        scene.anchors.append(boardScene!)
        
#if targetEnvironment(simulator)
        cameraMode = .nonAR
        let cameraEntity = PerspectiveCamera()
//        cameraEntity.camera.fieldOfViewInDegrees = 140 //Custom field of view
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(cameraEntity)
               
        scene.addAnchor(cameraAnchor)
        cameraEntity.look(at: SIMD3(repeating: 0), from: SIMD3(0,1,0), relativeTo: nil)
        gameAnchor = AnchorEntity()
#else
        setupARConfiguration()
#endif
        
        doECSTestSetup()
    }
    
    func registerComponents() {
        InvaderComponent.registerComponent()
    }
    
    func setupARConfiguration() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh){
            config.sceneReconstruction = .mesh
        }
        
        session.run(config)
        
        gameAnchor = AnchorEntity(.plane(.horizontal, classification: .table, minimumBounds: SIMD2(repeating: 0)))
    }
    
    func doECSTestSetup() {
        InvaderMotion.registerSystem()

        let xspacing = Utilities.spacing
        let yspacing = xspacing
        
        backgroundColor = .black
        
        for row in 1...1 {
            makeInvaderRow(onto: gameAnchor!, at: Float(row) * yspacing, withColumns: 9, withSpacing: xspacing)
        }
        
        gameAnchor!.setParent(boardScene!)
        gameAnchor!.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1,0,0])
        gameAnchor!.position.z -= 0.2
//        boardScene?.scene?.addAnchor(anchor)
        
        setInvader(shouldMove: true)
    }
    
    func setInvader(shouldMove: Bool) {
        scene.performQuery(InvaderMotion.query).forEach { entity in
            guard let model = entity as? ModelEntity else { return }
            
            guard let invader = model.components[InvaderComponent.self] as? InvaderComponent else { return }
            
            invader.doesMove = shouldMove
        }
    }
    
    func makeInvaderRow(onto anchor: AnchorEntity, at y: Float, withColumns cols: Int, withSpacing spacing: Float) {
        let low = 1-(cols/2) - cols % 2
        let high = cols/2
        
        let starting = cols % 2 > 0 ? 0 : -(spacing/2)
        
        for index in low...high {
            let currNum = index + 3
            
            let text = Utilities.getTextMesh(for: "\(currNum)")
 
            entity = ModelEntity(mesh: text,
                            materials: [UnlitMaterial()])
            entity?.position.x = starting + Float(index) * spacing
            entity?.position.y = y
            entity?.transform.rotation = simd_quatf(angle: .pi/4, axis: [1,0,0])
            entity?.setParent(anchor)
            entity?.name = "Prim\(currNum)"
            
            
            let limits: [(Float, Float)] = generateLimits(
                x: entity!.position.x,
                y: y,
                limitValue: Utilities.moveDistance,
                limitValueVertical: Utilities.moveDistanceVertical)
            print(limits)
            print(entity!.position.x)
            entity?.components[InvaderComponent.self] = InvaderComponent(limits: limits)
        }
    }
    
    func generateLimits(x: Float, y: Float, limitValue: Float, limitValueVertical: Float) -> [(Float, Float)] {
        return [(x+limitValue, 0), (x+limitValue, y-limitValueVertical), (x-limitValue, 0), (x-limitValue, y-limitValueVertical)]
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
