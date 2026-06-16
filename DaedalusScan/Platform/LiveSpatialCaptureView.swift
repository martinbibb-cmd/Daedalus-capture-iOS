import ARKit
#if canImport(RoomPlan)
import RoomPlan
#endif
import SceneKit
import SwiftUI

struct LiveSpatialCaptureView: UIViewRepresentable {
    @Binding var progress: LiveSpatialScanProgress
    @Binding var aim: LiveSpatialAim
    let isScanning: Bool
    let captureState: LiveCaptureState

    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress, aim: $aim)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        context.coordinator.containerView = container
        context.coordinator.configureCaptureAvailability()
        context.coordinator.setCaptureState(captureState)
        context.coordinator.setScanning(isScanning)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.setCaptureState(captureState)
        context.coordinator.setScanning(isScanning)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopSessions()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        private var progress: Binding<LiveSpatialScanProgress>
        private var aim: Binding<LiveSpatialAim>
        private var isRunning = false
        private var captureState: LiveCaptureState = .idle
        private var meshAnchorIDs = Set<String>()
        private var planeAnchorIDs = Set<String>()
        private var lastProgressUpdate = Date.distantPast
        private var lastAimUpdate = Date.distantPast
        var usesRoomPlan = false
        weak var containerView: UIView?
        weak var sceneView: ARSCNView?
        #if canImport(RoomPlan)
        @available(iOS 16.0, *)
        weak var roomCaptureView: RoomCaptureView?
        #endif

        init(progress: Binding<LiveSpatialScanProgress>, aim: Binding<LiveSpatialAim>) {
            self.progress = progress
            self.aim = aim
        }

        func configureCaptureAvailability() {
            #if canImport(RoomPlan)
            if #available(iOS 16.0, *) {
                usesRoomPlan = RoomCaptureSession.isSupported
            } else {
                usesRoomPlan = false
            }
            #else
            usesRoomPlan = false
            #endif
        }

        func add(_ child: UIView, to container: UIView) {
            child.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(child)
            NSLayoutConstraint.activate([
                child.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                child.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                child.topAnchor.constraint(equalTo: container.topAnchor),
                child.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }

        func setScanning(_ enabled: Bool) {
            guard enabled != isRunning else { return }
            isRunning = enabled
            if enabled {
                performSessionMutation {
                    self.runSurveySession()
                }
            } else {
                stopSessions()
            }
        }

        func setCaptureState(_ state: LiveCaptureState) {
            guard state != captureState else { return }
            let oldState = captureState
            captureState = state
            performSessionMutation {
                self.sceneView?.debugOptions = []
                self.clearTransientOverlays()
                guard self.isRunning else { return }
                if oldState.isFocusActive != state.isFocusActive {
                    self.stopSessionsNow()
                }
                self.runSurveySession(resetTracking: false, removeExistingAnchors: true)
            }
        }

        func stopSessions() {
            performSessionMutation {
                self.stopSessionsNow()
            }
        }

        private func performSessionMutation(_ operation: @escaping @MainActor () -> Void) {
            Task { @MainActor in
                operation()
            }
        }

        private func stopSessionsNow() {
            sceneView?.session.pause()
            clearTransientOverlays()
            #if canImport(RoomPlan)
            if #available(iOS 16.0, *) {
                roomCaptureView?.captureSession.stop()
            }
            #endif
        }

        private func runSurveySession(resetTracking: Bool = true, removeExistingAnchors: Bool = true) {
            if captureState.isFocusActive {
                runARKitSession(
                    resetTracking: resetTracking,
                    removeExistingAnchors: removeExistingAnchors,
                    sceneReconstruction: true,
                    capturePath: .focusPointCloud
                )
                return
            }

            #if canImport(RoomPlan)
            if #available(iOS 16.0, *), usesRoomPlan, let roomCaptureView = ensureRoomCaptureView() {
                sceneView?.session.pause()
                sceneView?.isHidden = true
                roomCaptureView.isHidden = false
                let configuration = RoomCaptureSession.Configuration()
                roomCaptureView.captureSession.run(configuration: configuration)
                publishRoomPlanProgress(elementCount: 0)
                return
            }
            #endif

            runARKitSession(
                resetTracking: resetTracking,
                removeExistingAnchors: removeExistingAnchors,
                sceneReconstruction: false,
                capturePath: .arkitFallback
            )
        }

        private func runARKitSession(
            resetTracking: Bool = true,
            removeExistingAnchors: Bool = true,
            sceneReconstruction: Bool,
            capturePath: LiveSpatialCapturePath
        ) {
            guard ARWorldTrackingConfiguration.isSupported else { return }
            guard let sceneView = ensureSceneView() else { return }
            #if canImport(RoomPlan)
            if #available(iOS 16.0, *) {
                roomCaptureView?.captureSession.stop()
                roomCaptureView?.isHidden = true
            }
            #endif
            sceneView.isHidden = false
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            if sceneReconstruction,
               ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
            sceneView.debugOptions = []
            var options: ARSession.RunOptions = []
            if resetTracking {
                options.insert(.resetTracking)
            }
            if removeExistingAnchors {
                options.insert(.removeExistingAnchors)
            }
            sceneView.session.run(configuration, options: options)
            publishARProgress(capturePath: capturePath)
        }

        private func ensureSceneView() -> ARSCNView? {
            if let sceneView {
                return sceneView
            }
            guard let containerView else { return nil }
            let arView = ARSCNView(frame: .zero)
            arView.delegate = self
            arView.automaticallyUpdatesLighting = true
            arView.scene = SCNScene()
            arView.debugOptions = []
            arView.isHidden = true
            sceneView = arView
            add(arView, to: containerView)
            return arView
        }

        #if canImport(RoomPlan)
        @available(iOS 16.0, *)
        private func ensureRoomCaptureView() -> RoomCaptureView? {
            if let roomCaptureView {
                return roomCaptureView
            }
            guard let containerView else { return nil }
            let roomView = RoomCaptureView(frame: .zero)
            roomView.captureSession.delegate = self
            roomCaptureView = roomView
            add(roomView, to: containerView)
            return roomView
        }
        #endif

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            publishAimIfNeeded()
            updateNode(node, for: anchor)
            record(anchor: anchor)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            publishAimIfNeeded()
            updateNode(node, for: anchor)
            record(anchor: anchor)
        }

        private func updateNode(_ node: SCNNode, for anchor: ARAnchor) {
            node.geometry = nil
            node.childNodes.forEach { $0.removeFromParentNode() }

            if let meshAnchor = anchor as? ARMeshAnchor {
                node.geometry = nil
                if captureState.isFocusActive {
                    node.addChildNode(focusPointCloudNode(for: meshAnchor.geometry))
                }
            } else if let planeAnchor = anchor as? ARPlaneAnchor {
                if !captureState.isFocusActive {
                    node.addChildNode(planeOutlineNode(for: planeAnchor))
                }
            }
        }

        private func planeOutlineNode(for planeAnchor: ARPlaneAnchor) -> SCNNode {
            let width = CGFloat(max(planeAnchor.planeExtent.width, 0.08))
            let height = CGFloat(max(planeAnchor.planeExtent.height, 0.08))
            let centerX = CGFloat(planeAnchor.center.x)
            let centerZ = CGFloat(planeAnchor.center.z)
            let halfWidth = width / 2
            let halfHeight = height / 2

            let vertices = [
                SCNVector3(centerX - halfWidth, 0, centerZ - halfHeight),
                SCNVector3(centerX + halfWidth, 0, centerZ - halfHeight),
                SCNVector3(centerX + halfWidth, 0, centerZ + halfHeight),
                SCNVector3(centerX - halfWidth, 0, centerZ + halfHeight)
            ]
            let source = SCNGeometrySource(vertices: vertices)
            let indices: [Int32] = [0, 1, 1, 2, 2, 3, 3, 0]
            let element = indices.withUnsafeBufferPointer { pointer in
                SCNGeometryElement(
                    data: Data(buffer: pointer),
                    primitiveType: .line,
                    primitiveCount: 4,
                    bytesPerIndex: MemoryLayout<Int32>.size
                )
            }
            let geometry = SCNGeometry(sources: [source], elements: [element])
            geometry.firstMaterial = outlineMaterial()

            return SCNNode(geometry: geometry)
        }

        private func focusPointCloudNode(for meshGeometry: ARMeshGeometry) -> SCNNode {
            let vertices = sampledMeshVertices(from: meshGeometry, maximumCount: 1_500)
            guard !vertices.isEmpty else {
                return SCNNode()
            }

            let source = SCNGeometrySource(vertices: vertices)
            let indices = (0..<Int32(vertices.count)).map { $0 }
            let element = indices.withUnsafeBufferPointer { pointer in
                SCNGeometryElement(
                    data: Data(buffer: pointer),
                    primitiveType: .point,
                    primitiveCount: vertices.count,
                    bytesPerIndex: MemoryLayout<Int32>.size
                )
            }
            element.pointSize = 5
            element.minimumPointScreenSpaceRadius = 2
            element.maximumPointScreenSpaceRadius = 7

            let geometry = SCNGeometry(sources: [source], elements: [element])
            geometry.firstMaterial = focusPointMaterial()
            return SCNNode(geometry: geometry)
        }

        private func sampledMeshVertices(from meshGeometry: ARMeshGeometry, maximumCount: Int) -> [SCNVector3] {
            let source = meshGeometry.vertices
            guard source.count > 0 else { return [] }

            let sampleCount = min(source.count, maximumCount)
            let step = max(source.count / sampleCount, 1)
            let basePointer = source.buffer.contents().advanced(by: source.offset)
            var vertices: [SCNVector3] = []
            vertices.reserveCapacity(sampleCount)

            for vertexIndex in stride(from: 0, to: source.count, by: step) {
                guard vertices.count < sampleCount else { break }
                let vertexPointer = basePointer.advanced(by: vertexIndex * source.stride)
                let values = vertexPointer.assumingMemoryBound(to: Float.self)
                vertices.append(SCNVector3(values[0], values[1], values[2]))
            }

            return vertices
        }

        private func outlineMaterial() -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.88)
            material.emission.contents = UIColor.white.withAlphaComponent(0.36)
            material.lightingModel = .constant
            material.isDoubleSided = true
            material.readsFromDepthBuffer = true
            material.writesToDepthBuffer = false
            return material
        }

        private func focusPointMaterial() -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.92)
            material.emission.contents = UIColor.white.withAlphaComponent(0.44)
            material.lightingModel = .constant
            material.readsFromDepthBuffer = true
            material.writesToDepthBuffer = false
            return material
        }

        private func record(anchor: ARAnchor) {
            if anchor is ARMeshAnchor {
                meshAnchorIDs.insert(anchor.identifier.uuidString)
            } else if anchor is ARPlaneAnchor {
                planeAnchorIDs.insert(anchor.identifier.uuidString)
            } else {
                return
            }
            guard Date().timeIntervalSince(lastProgressUpdate) >= 0.25 else {
                return
            }
            lastProgressUpdate = Date()
            publishARProgress(
                anchorID: anchor.identifier.uuidString,
                position: SpatialPosition(
                    x: Double(anchor.transform.columns.3.x),
                    y: Double(anchor.transform.columns.3.y),
                    z: Double(anchor.transform.columns.3.z)
                ),
                capturePath: captureState.isFocusActive ? .focusPointCloud : .arkitFallback
            )
        }

        private func clearTransientOverlays() {
            meshAnchorIDs.removeAll()
            planeAnchorIDs.removeAll()
            sceneView?.scene.rootNode.childNodes.forEach { node in
                node.geometry = nil
                node.childNodes.forEach { $0.removeFromParentNode() }
            }
        }

        private func publishARProgress(
            anchorID: String? = nil,
            position: SpatialPosition? = nil,
            capturePath: LiveSpatialCapturePath
        ) {
            let updated = LiveSpatialScanProgress(
                meshAnchorCount: meshAnchorIDs.count,
                planeAnchorCount: planeAnchorIDs.count,
                lastAnchorID: anchorID,
                lastKnownPosition: position,
                lastUpdatedAt: Date(),
                capturePath: capturePath
            )
            DispatchQueue.main.async {
                self.progress.wrappedValue = updated
            }
        }

        private func publishRoomPlanProgress(elementCount: Int, updatedAt: Date = Date()) {
            let updated = LiveSpatialScanProgress(
                roomElementCount: elementCount,
                lastUpdatedAt: updatedAt,
                capturePath: .roomPlan
            )
            DispatchQueue.main.async {
                self.progress.wrappedValue = updated
            }
        }

        private func publishAimIfNeeded() {
            guard Date().timeIntervalSince(lastAimUpdate) >= 0.25 else {
                return
            }
            lastAimUpdate = Date()
            guard let sceneView else { return }

            let devicePosition = sceneView.session.currentFrame.map { frame in
                SpatialPosition(
                    x: Double(frame.camera.transform.columns.3.x),
                    y: Double(frame.camera.transform.columns.3.y),
                    z: Double(frame.camera.transform.columns.3.z)
                )
            }
            let center = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
            let targetPosition = centerRaycastTarget(in: sceneView, at: center)

            DispatchQueue.main.async {
                self.aim.wrappedValue = LiveSpatialAim(
                    devicePosition: devicePosition,
                    targetPosition: targetPosition,
                    updatedAt: Date()
                )
            }
        }

        @available(iOS 16.0, *)
        fileprivate func publishRoomPlanAimIfNeeded(from session: RoomCaptureSession) {
            guard Date().timeIntervalSince(lastAimUpdate) >= 0.25 else {
                return
            }
            lastAimUpdate = Date()
            let arSession = session.arSession
            guard let frame = arSession.currentFrame else { return }

            let devicePosition = SpatialPosition(
                x: Double(frame.camera.transform.columns.3.x),
                y: Double(frame.camera.transform.columns.3.y),
                z: Double(frame.camera.transform.columns.3.z)
            )
            let targetPosition = forwardRaycastTarget(in: arSession, frame: frame)

            DispatchQueue.main.async {
                self.aim.wrappedValue = LiveSpatialAim(
                    devicePosition: devicePosition,
                    targetPosition: targetPosition,
                    updatedAt: Date()
                )
            }
        }

        private func centerRaycastTarget(in sceneView: ARSCNView, at point: CGPoint) -> SpatialPosition? {
            guard let frame = sceneView.session.currentFrame else {
                return nil
            }
            if let query = sceneView.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any),
               let result = sceneView.session.raycast(query).first {
                return SpatialPosition(
                    x: Double(result.worldTransform.columns.3.x),
                    y: Double(result.worldTransform.columns.3.y),
                    z: Double(result.worldTransform.columns.3.z)
                )
            }
            return forwardRaycastTarget(in: sceneView.session, frame: frame)
        }

        private func forwardRaycastTarget(in session: ARSession, frame: ARFrame) -> SpatialPosition {
            let transform = frame.camera.transform
            let origin = transform.columns.3
            let forward = simd_float3(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
            let queryOrigin = simd_float3(origin.x, origin.y, origin.z)
            let query = ARRaycastQuery(origin: queryOrigin, direction: forward, allowing: .estimatedPlane, alignment: .any)
            if let result = session.raycast(query).first {
                return SpatialPosition(
                    x: Double(result.worldTransform.columns.3.x),
                    y: Double(result.worldTransform.columns.3.y),
                    z: Double(result.worldTransform.columns.3.z)
                )
            }
            let target = queryOrigin + forward * 1.5
            return SpatialPosition(x: Double(target.x), y: Double(target.y), z: Double(target.z))
        }

    }
}

#if canImport(RoomPlan)
@available(iOS 16.0, *)
extension LiveSpatialCaptureView.Coordinator: RoomCaptureSessionDelegate {
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        publishRoomPlanAimIfNeeded(from: session)
        let elementCount = room.walls.count + room.doors.count + room.windows.count + room.openings.count + room.objects.count
        publishRoomPlanProgress(elementCount: elementCount)
    }
}
#endif

private extension SCNGeometry {
    convenience init(arMeshGeometry: ARMeshGeometry) {
        let vertices = arMeshGeometry.vertices.asSource(semantic: .vertex)
        let faces = arMeshGeometry.faces.asElement()
        self.init(sources: [vertices], elements: [faces])
    }
}

private extension ARGeometrySource {
    func asSource(semantic: SCNGeometrySource.Semantic) -> SCNGeometrySource {
        SCNGeometrySource(
            buffer: buffer,
            vertexFormat: format,
            semantic: semantic,
            vertexCount: count,
            dataOffset: offset,
            dataStride: stride
        )
    }
}

private extension ARGeometryElement {
    func asElement() -> SCNGeometryElement {
        SCNGeometryElement(
            data: Data(bytesNoCopy: buffer.contents(), count: count * bytesPerIndex * indexCountPerPrimitive, deallocator: .none),
            primitiveType: .triangles,
            primitiveCount: count,
            bytesPerIndex: bytesPerIndex
        )
    }
}
