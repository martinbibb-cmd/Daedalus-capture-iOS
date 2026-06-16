import ARKit
#if canImport(RoomPlan)
import RoomPlan
#endif
import SceneKit
import SwiftUI

struct LiveSpatialCaptureView: UIViewRepresentable {
    @Binding var progress: LiveSpatialScanProgress
    let isScanning: Bool
    let isFocusModeActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        context.coordinator.containerView = container
        context.coordinator.configureCaptureAvailability()
        context.coordinator.setFocusMode(isFocusModeActive)
        context.coordinator.setScanning(isScanning)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.setFocusMode(isFocusModeActive)
        context.coordinator.setScanning(isScanning)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopSessions()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        private var progress: Binding<LiveSpatialScanProgress>
        private var isRunning = false
        private var isFocusModeActive = false
        private var meshAnchorIDs = Set<String>()
        private var planeAnchorIDs = Set<String>()
        private var lastProgressUpdate = Date.distantPast
        var usesRoomPlan = false
        weak var containerView: UIView?
        weak var sceneView: ARSCNView?
        #if canImport(RoomPlan)
        @available(iOS 16.0, *)
        weak var roomCaptureView: RoomCaptureView?
        #endif

        init(progress: Binding<LiveSpatialScanProgress>) {
            self.progress = progress
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
                runSurveySession()
            } else {
                stopSessions()
            }
        }

        func setFocusMode(_ enabled: Bool) {
            guard enabled != isFocusModeActive else { return }
            isFocusModeActive = enabled
            sceneView?.debugOptions = []
            guard isRunning else { return }
            runSurveySession(resetTracking: false, removeExistingAnchors: !enabled)
        }

        func stopSessions() {
            sceneView?.session.pause()
            #if canImport(RoomPlan)
            if #available(iOS 16.0, *) {
                roomCaptureView?.captureSession.stop()
            }
            #endif
        }

        private func runSurveySession(resetTracking: Bool = true, removeExistingAnchors: Bool = true) {
            if isFocusModeActive {
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
            updateNode(node, for: anchor)
            record(anchor: anchor)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            updateNode(node, for: anchor)
            record(anchor: anchor)
        }

        private func updateNode(_ node: SCNNode, for anchor: ARAnchor) {
            node.geometry = nil
            node.childNodes.forEach { $0.removeFromParentNode() }

            if let meshAnchor = anchor as? ARMeshAnchor {
                node.geometry = nil
                if isFocusModeActive {
                    node.addChildNode(focusPointCloudNode(for: meshAnchor.geometry))
                }
            } else if let planeAnchor = anchor as? ARPlaneAnchor {
                node.addChildNode(planeOutlineNode(for: planeAnchor))
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
            let vertices = sampledMeshVertices(from: meshGeometry, maximumCount: 220)
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
            material.diffuse.contents = UIColor.white.withAlphaComponent(isFocusModeActive ? 0.96 : 0.88)
            material.emission.contents = UIColor.white.withAlphaComponent(isFocusModeActive ? 0.52 : 0.36)
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
                capturePath: isFocusModeActive ? .focusPointCloud : .arkitFallback
            )
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
    }
}

#if canImport(RoomPlan)
@available(iOS 16.0, *)
extension LiveSpatialCaptureView.Coordinator: RoomCaptureSessionDelegate {
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
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
