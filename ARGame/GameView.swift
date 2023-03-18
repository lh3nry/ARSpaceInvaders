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
    static let spacing: Float = 0.015
    static let moveDistance: Float = 0.07
    static let moveDistanceVertical: Float = 0.025
    static let maxSpeed: Float = 0.2
    
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
    
    let moves: [(x: Float, z: Float)] = [(1,0), (0,1), (-1,0), (0,1)]
    let stateCount = 4
    
    func isValue(_ a: Float, closeTo b: Float, withTolerance tol: Float = 1e-6) -> Bool {
        return abs(a-b) < tol
    }
        
    func update(context: SceneUpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            guard let model = entity as? ModelEntity else { return }
            
            guard let invader = model.components[InvaderComponent.self] as? InvaderComponent else { return }
            
            if !invader.doesMove { return }
        
            let xlimit = invader.limits[invader.moveState].x
            
            if invader.moveState == 0 && xlimit > 0 && model.position.x > xlimit {
                model.position.x = xlimit - invader.speed * Float(context.deltaTime)
                invader.moveState = (invader.moveState + 1) % stateCount
                model.model?.mesh = Utilities.getTextMesh(for: "\(invader.moveState)")
            }
            else if invader.moveState == 2 && xlimit < 0 && model.position.x < xlimit {
                model.position.x = xlimit + invader.speed * Float(context.deltaTime)
                invader.moveState = (invader.moveState + 1) % stateCount
                model.model?.mesh = Utilities.getTextMesh(for: "\(invader.moveState)")
            }
            else if (invader.moveState == 1 || invader.moveState == 3) && model.position.z > invader.limits[invader.moveState].z {
//                print("\(invader.moveState) \(invader.limits[invader.moveState]) pos (\(model.position.x), \(model.position.y)), move (\(moves[invader.moveState]) ")
//                model.position.y -= Float(context.deltaTime) * moves[invader.moveState].y
                invader.moveState = (invader.moveState + 1) % stateCount
                model.model?.mesh = Utilities.getTextMesh(for: "\(invader.moveState)")

                invader.limits[1].z += Utilities.moveDistanceVertical
                invader.limits[3].z += Utilities.moveDistanceVertical
                invader.speed = min(invader.speed + 0.03, Utilities.maxSpeed)
            }
            else {
                model.position.x += invader.speed * Float(context.deltaTime) * moves[invader.moveState].x
                model.position.z += invader.speed * Float(context.deltaTime) * moves[invader.moveState].z
            }
        }
    }
}

class InvaderComponent: Component {
    var limits: [(x: Float, z: Float)]
    var moveState = 0
    var doesMove = false
    var speed: Float = 0.05
    
    init(limits: [(x: Float, z: Float)]) {
        self.limits = limits
    }
}

class SpatialView: ARView {
    var updateSub, gameLossSub: Cancellable!
    
    var cubeEntity, entity: ModelEntity?
    var boardScene: Gameboard.Scene?
    var gameAnchor: AnchorEntity?
    var boardAnchor: AnchorEntity?
    
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
        NotificationCenter.default.addObserver(self, selector: #selector(self.fireWeapon), name: .weaponFiredEvent, object: nil)
        
        
#if targetEnvironment(simulator)
        cameraMode = .nonAR
        let cameraEntity = PerspectiveCamera()
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(cameraEntity)
               
        scene.addAnchor(cameraAnchor)
        cameraEntity.look(at: SIMD3(repeating: 0), from: SIMD3(0,1,0), upVector: [0,0,-1], relativeTo: nil)
        gameAnchor = AnchorEntity()
#else
        setupARConfiguration()
#endif
        doGameSetup()
        
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
    
    func doGameSetup() {
        try! loadScene()
        
        scene.addAnchor(boardAnchor!)
        
        var shape = ShapeResource.generateBox(width: 0.3, height: 0.05, depth: 0.05)
        shape = shape.offsetBy(translation: [0,0.03,0.225])
        let collider = TriggerVolume(shapes: [shape])
        collider.generateCollisionShapes(recursive: true)
        collider.collision?.mode = .trigger
        
        gameLossSub = scene.subscribe(to: CollisionEvents.Began.self, on: collider) { [unowned self] in
            gameLossColliderHit(event: $0)
        }
        
        collider.setParent(boardAnchor!, preservingWorldTransform: true)
    }
    
    func doECSTestSetup() {
        InvaderMotion.registerSystem()

        let xspacing = Utilities.spacing
        let yspacing = xspacing
        
//        backgroundColor = .black

        for row in -16...(-10) {
            makeInvaderRow(onto: boardAnchor!, at: Float(row) * yspacing, withColumns: 9, withSpacing: xspacing)
        }

        setInvader(shouldMove: true)
    }
    
    @objc func fireWeapon() {
        print("SpatialView: fire weapon")
    }
    
    func gameLossColliderHit(event: CollisionEvents.Began) {
        print("GameLost")
//        print("EntityA: \(event.entityA) EntityB: \(event.entityB)")
        setInvader(shouldMove: false)
    }
    
    func setInvader(shouldMove: Bool) {
        scene.performQuery(InvaderMotion.query).forEach { entity in
            guard let model = entity as? ModelEntity else { return }
            
            guard let invader = model.components[InvaderComponent.self] as? InvaderComponent else { return }
            
            invader.doesMove = shouldMove
        }
    }
    
    func makeInvaderRow(onto anchor: AnchorEntity, at z: Float, withColumns cols: Int, withSpacing spacing: Float) {
        let low = 1-(cols/2) - cols % 2
        let high = cols/2
        
        let starting = cols % 2 > 0 ? 0 : -(spacing/2)
        
        for index in low...high {
            let currNum = index + 3
            
            let text = Utilities.getTextMesh(for: "\(currNum)")
 
            entity = ModelEntity(mesh: text,
                            materials: [UnlitMaterial()])

            anchor.addChild(entity!, preservingWorldTransform: false)
            entity?.setPosition(SIMD3(starting + Float(index) * spacing, 0, z), relativeTo: anchor)

            entity?.transform.rotation = simd_quatf(angle: .pi/4, axis: [-1,0,0])
            entity?.name = "Invader\(currNum)"
            
            let limits: [(Float, Float)] = generateLimits(
                x: entity!.position.x,
                z: z,
                limitValue: Utilities.moveDistance,
                limitValueVertical: Utilities.moveDistanceVertical)
            print(limits)
            print(entity!.position.x)
            entity?.components[InvaderComponent.self] = InvaderComponent(limits: limits)
            entity?.generateCollisionShapes(recursive: true)
        }
    }
    
    func createScene(from anchorEntity: RealityKit.AnchorEntity) -> Gameboard.Scene {
        let scene = Gameboard.Scene()
        scene.anchoring = anchorEntity.anchoring
        scene.addChild(anchorEntity)
        return scene
    }
    
    func loadScene() throws {
        guard let realityFileURL = Foundation.Bundle(for: Gameboard.Scene.self).url(forResource: "gameboard", withExtension: "reality") else {
            throw Gameboard.LoadRealityFileError.fileNotFound("gameboard.reality")
        }

        let realityFileSceneURL = realityFileURL.appendingPathComponent("Scene", isDirectory: false)
        boardAnchor = try Gameboard.Scene.loadAnchor(contentsOf: realityFileSceneURL)
    }
    
    func generateLimits(x: Float, z: Float, limitValue: Float, limitValueVertical: Float) -> [(Float, Float)] {
        return [(x+limitValue, 0), (x+limitValue, z+limitValueVertical), (x-limitValue, 0), (x-limitValue, z+limitValueVertical)]
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
