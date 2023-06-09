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
    static var maxSpeed: Float = 0.2
    static var numRows: Int = 5
    
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

extension Comparable {
    func clamped(_ f: Self, _ t: Self)  ->  Self {
        var r = self
        if r < f { r = f }
        if r > t { r = t }
        // (use SIMPLE, EXPLICIT code here to make it utterly clear
        // whether we are inclusive, what form of equality, etc etc)
        return r
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
//                model.model?.mesh = Utilities.getTextMesh(for: "\(invader.moveState)")
            }
            else if invader.moveState == 2 && xlimit < 0 && model.position.x < xlimit {
                model.position.x = xlimit + invader.speed * Float(context.deltaTime)
                invader.moveState = (invader.moveState + 1) % stateCount
//                model.model?.mesh = Utilities.getTextMesh(for: "\(invader.moveState)")
            }
            else if (invader.moveState == 1 || invader.moveState == 3) && model.position.z > invader.limits[invader.moveState].z {
//                print("\(invader.moveState) \(invader.limits[invader.moveState]) pos (\(model.position.x), \(model.position.y)), move (\(moves[invader.moveState]) ")
//                model.position.y -= Float(context.deltaTime) * moves[invader.moveState].y
                invader.moveState = (invader.moveState + 1) % stateCount
//                model.model?.mesh = Utilities.getTextMesh(for: "\(invader.moveState)")

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
    var updateSub, gameLossSub, invaderHitSub, bulletSpongeSub: Cancellable!
    
    var cubeEntity, entity, playerModel: ModelEntity?
    var boardScene: Gameboard.Scene?
    var boardAnchor: AnchorEntity?
    
    var bulletGroup,
        invaderGroup,
        gameLossGroup,
        invaderMask,
        bulletSpongeGroup: CollisionGroup?
    
//    var boardAnchorEntities: [Entity] = []
    
    var parentView: ContentView?
    
    var invaderCounter: Int = 0
    
    var models: [ModelEntity] = []
    
    required init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        isMultipleTouchEnabled = true
    }

    override var canBecomeFirstResponder: Bool { true }

    func setup(parentView: any View, models: [ModelEntity]) {
        registerComponents()
        doCollisionGroupSetup()
//        doCubeSetup()
        NotificationCenter.default.addObserver(self, selector: #selector(self.fireWeapon), name: .weaponFiredEvent, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.restart), name: .restartGameEvent, object: nil)

        self.parentView = parentView as? ContentView
        self.models = models
        
#if targetEnvironment(simulator)
        cameraMode = .nonAR
        let cameraEntity = PerspectiveCamera()
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(cameraEntity)
               
        scene.addAnchor(cameraAnchor)
        cameraEntity.look(at: SIMD3(repeating: 0), from: SIMD3(0,1,0), upVector: [0,0,-1], relativeTo: nil)
#else
        setupARConfiguration()
#endif
        
        // Note the order to prevent a game win before invaders have been setup
        // and save an extra state variable/flag for setup
        doLoadScene()
        doECSTestSetup()
        doGameSetup()
    }
    
    func registerComponents() {
        InvaderComponent.registerComponent()
    }
    
    func doCollisionGroupSetup() {
        bulletGroup = CollisionGroup(rawValue: 1)
        invaderGroup = CollisionGroup(rawValue: 2)
        gameLossGroup = CollisionGroup(rawValue: 4)
        bulletSpongeGroup = CollisionGroup(rawValue: 8)
        invaderMask = bulletGroup!.union(gameLossGroup!)
    }
    
    func setupARConfiguration() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh){
            config.sceneReconstruction = .mesh
        }
        
        session.run(config)
    }
    
    @objc func restart() {
        // TODO: separate option to reanchor vs restart without reanchoring?
//        for entity in boardAnchorEntities {
//            entity.removeFromParent()
//        }
//        boardAnchorEntities.removeAll(keepingCapacity: false)
        
        print("boardAnchor children size: \(String(describing: boardAnchor?.children.count))")
        boardAnchor?.children.removeAll(keepCapacity: false)
        print("boardAnchor children size: \(String(describing: boardAnchor?.children.count))")
        boardAnchor?.removeFromParent()
        boardAnchor = nil
        
        entity = nil
        playerModel = nil
        
//        scene.anchors.removeAll()
        
        // Note the order to prevent a game win before invaders have been setup
        // and save an extra state variable/flag for setup
        doLoadScene()
        doECSTestSetup()
        doGameSetup()
    }
    
    func doLoadScene() {
        try! loadScene()
        
        scene.addAnchor(boardAnchor!)
    }
    
    func doGameSetup() {
        var shape = ShapeResource.generateBox(width: 0.3, height: 0.05, depth: 0.05)
        shape = shape.offsetBy(translation: [0,0.03,0.225])
        let collider = TriggerVolume(shapes: [shape])
        collider.collision?.mode = .trigger
        collider.collision?.filter = CollisionFilter(group: gameLossGroup!, mask: invaderGroup!)
        
        gameLossSub = scene.subscribe(to: CollisionEvents.Began.self, on: collider) { [unowned self] in
            gameLossColliderHit(event: $0)
        }
        
        collider.setParent(boardAnchor!, preservingWorldTransform: true)
//        boardAnchorEntities.append(collider)
        
        var sponge = ShapeResource.generateBox(width: 0.3, height: 0.05, depth: 0.05)
        sponge = sponge.offsetBy(translation: [0,0.03,-0.255])
        let bulletSponge = TriggerVolume(
            shapes: [sponge],
            filter: CollisionFilter(group: bulletSpongeGroup!, mask: bulletGroup!))
        bulletSponge.collision?.mode = .trigger

        
        bulletSpongeSub = scene.subscribe(to: CollisionEvents.Began.self, on: bulletSponge) { [unowned self] event in
            bulletSpongeHit(event: event)
        }
        
        bulletSponge.setParent(boardAnchor!, preservingWorldTransform: true)
//        boardAnchorEntities.append(bulletSponge)

        let shipModel = models[0].clone(recursive: false)
//        shipModel.transform.rotation = simd_quatf(angle: -.pi/2, axis: SIMD3([1,0,0]))
        shipModel.setParent(boardAnchor!, preservingWorldTransform: false)
//        boardAnchorEntities.append(shipModel)
        shipModel.setPosition(SIMD3([0,0.01,0.22]), relativeTo: boardAnchor!)
        
        let material = SimpleMaterial(color: .systemPink, isMetallic: true)
        shipModel.model?.materials = [material]
        
        playerModel = shipModel
        updateSub = scene.subscribe(to: SceneEvents.Update.self) { [unowned self] in
            self.playerUpdate(on: $0)
        }
    }
    
    func doECSTestSetup() {
        InvaderMotion.registerSystem()

        let xspacing = Utilities.spacing
        let yspacing = xspacing
        
        invaderCounter = 0

        let startZ = -16
        for row in startZ...(startZ+Utilities.numRows-1) {
            makeInvaderRow(onto: boardAnchor!, at: Float(row) * yspacing, withColumns: 9, withSpacing: xspacing)
        }
    }
    
    @objc func fireWeapon() {
        let bulletEntity = ModelEntity(mesh: .generateSphere(radius: 0.5)) as (ModelEntity & HasCollision & HasPhysicsBody & HasPhysicsMotion)
        bulletEntity.name = "bullet"
        bulletEntity.generateCollisionShapes(recursive: true)
//        bulletEntity.collision = CollisionComponent(shapes: [ShapeResource.generateBox(width: 0.003, height: 0.005, depth: 0.003)])
        bulletEntity.collision?.filter = CollisionFilter(group: bulletGroup!, mask: invaderGroup!.union(bulletSpongeGroup!))
        invaderHitSub = scene.subscribe(to: CollisionEvents.Began.self, on: bulletEntity) { [unowned self] in
            invaderHit(event: $0)
        }
        
//        bulletEntity.physicsBody = PhysicsBodyComponent(massProperties: .default, material: .default, mode: .dynamic)
        bulletEntity.physicsBody = PhysicsBodyComponent(massProperties: .default, material: .default, mode: .kinematic)

        bulletEntity.physicsBody?.isTranslationLocked = (false, true, false)
        bulletEntity.physicsBody?.isRotationLocked = (true, true, true)
        
        let material = SimpleMaterial(color: .blue, isMetallic: false)
        bulletEntity.model?.materials = [material]
        
        if let unwrapped = playerModel {
            unwrapped.addChild(bulletEntity, preservingWorldTransform: false)
            bulletEntity.setPosition([0,1,0], relativeTo: unwrapped)
//            bulletEntity.applyLinearImpulse(SIMD3([0,0,-1]), relativeTo: unwrapped.parent)
            bulletEntity.physicsMotion = PhysicsMotionComponent(linearVelocity: [0,0,-1])
        }
    }
    
    func gameLossColliderHit(event: CollisionEvents.Began) {
        setInvader(shouldMove: false)
        parentView?.arGameLost()
    }
    
    func bulletSpongeHit(event: CollisionEvents.Began) {
//        print("bullet struck sponge A: \(event.entityA), B: \(event.entityB)")
        
        let tempAnchor = AnchorEntity()
        scene.addAnchor(tempAnchor)
        if event.entityA.name == "bullet" { event.entityA.setParent(tempAnchor) }
        if event.entityB.name == "bullet" { event.entityB.setParent(tempAnchor) }
        scene.removeAnchor(tempAnchor)
    }
    
    func invaderHit(event: CollisionEvents.Began) {
        invaderCounter -= 1
        
        let tempAnchor = AnchorEntity()
        scene.addAnchor(tempAnchor)
        event.entityA.setParent(tempAnchor)
        event.entityB.setParent(tempAnchor)
        scene.removeAnchor(tempAnchor)
//        invaderHitSub = nil
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
        let modelCount = models.count - 1
        
        // TODO: understand CustomMaterials and how to use metal to create emissive colors
        // need to understand metal default library or GeometryModifiers and shaders
//        let mtlLibrary = MTLCreateSystemDefaultDevice()!.makeDefaultLibrary()
        
        for index in low...high {
            entity = models[Int.random(in: 1...modelCount)].clone(recursive: false)

            if let unwrapped = entity {
                anchor.addChild(unwrapped, preservingWorldTransform: false)
//                boardAnchorEntities.append(unwrapped)

                unwrapped.setPosition(SIMD3(starting + Float(index) * spacing, 0.01, z), relativeTo: anchor)

                unwrapped.setScale(SIMD3(repeating: 1.5), relativeTo: unwrapped)
                unwrapped.transform.rotation = simd_quatf(angle: .pi/4, axis: [-1,0,0])
                unwrapped.name = "👾"
                
                let material = SimpleMaterial(color: .green, isMetallic: false)
                unwrapped.model?.materials = [material]
                
                let limits: [(Float, Float)] = generateLimits(
                    x: unwrapped.position.x,
                    z: z,
                    limitValue: Utilities.moveDistance,
                    limitValueVertical: Utilities.moveDistanceVertical)

//                print(unwrapped.position.x)
                unwrapped.components[InvaderComponent.self] = InvaderComponent(limits: limits)
                unwrapped.generateCollisionShapes(recursive: true)
                unwrapped.collision?.filter = CollisionFilter(group: invaderGroup!, mask: bulletGroup!.union(gameLossGroup!))
                
                invaderCounter += 1
            }
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
    
    func playerUpdate(on event: SceneEvents.Update) {
        // Note: can't use this code because the QueryResults will use the
        // Sequence protocol default implementation for underestimatedCount
        // which always returns 0
//        let invaders = scene.performQuery(InvaderMotion.query)
//        if invaders.underestimatedCount == 0 {
//            parentView?.onGameWon()
//        }
        
        // Use a counter instead
        if invaderCounter < 1 {
            parentView?.onGameWon()
        }
        
        let viewCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        
        if let ray =  self.ray(through: viewCenter) {
            let results = scene.raycast(origin: ray.origin, direction: ray.direction, length: 3.0, query: .nearest)

            if let result = results.first {
                let pos = result.position
                playerModel?.transform.translation.x = pos.x.clamped(-0.125, 0.125)
            }
        }
    }
}
