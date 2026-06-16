import ARKit
import SceneKit
import SwiftUI

struct LiveSpatialCaptureView: UIViewRepresentable {
    @Binding var progress: LiveSpatialScanProgress
    let isScanning: Bool
    let isFocusModeActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        context.coordinator.sceneView = view
        context.coordinator.setFocusMode(isFocusModeActive)
        context.coordinator.setScanning(isScanning)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.setFocusMode(isFocusModeActive)
        context.coordinator.setScanning(isScanning)
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        private var progress: Binding<LiveSpatialScanProgress>
        private var isRunning = false
        private var isFocusModeActive = false
        private var meshAnchorIDs = Set<String>()
        private var planeAnchorIDs = Set<String>()
        private var lastProgressUpdate = Date.distantPast
        weak var sceneView: ARSCNView?

        init(progress: Binding<LiveSpatialScanProgress>) {
            self.progress = progress
        }

        func setScanning(_ enabled: Bool) {
            guard enabled != isRunning else { return }
            isRunning = enabled
            if enabled {
                runSession()
            } else {
                sceneView?.session.pause()
            }
        }

        func setFocusMode(_ enabled: Bool) {
            guard enabled != isFocusModeActive else { return }
            isFocusModeActive = enabled
            sceneView?.debugOptions = enabled ? [.showFeaturePoints] : []
            guard isRunning else { return }
            runSession(resetTracking: false, removeExistingAnchors: !enabled)
        }

        private func runSession(resetTracking: Bool = true, removeExistingAnchors: Bool = true) {
            guard ARWorldTrackingConfiguration.isSupported else { return }
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            if isFocusModeActive,
               ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
            sceneView?.debugOptions = isFocusModeActive ? [.showFeaturePoints] : []
            var options: ARSession.RunOptions = []
            if resetTracking {
                options.insert(.resetTracking)
            }
            if removeExistingAnchors {
                options.insert(.removeExistingAnchors)
            }
            sceneView?.session.run(configuration, options: options)
        }

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            updateNode(node, for: anchor)
            record(anchor: anchor)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            updateNode(node, for: anchor)
            record(anchor: anchor)
        }

        private func updateNode(_ node: SCNNode, for anchor: ARAnchor) {
            if anchor is ARMeshAnchor {
                node.geometry = nil
                node.childNodes.forEach { $0.removeFromParentNode() }
                if isFocusModeActive {
                    node.addChildNode(focusMarkerNode())
                }
            } else if let planeAnchor = anchor as? ARPlaneAnchor {
                let plane = SCNPlane(width: CGFloat(planeAnchor.planeExtent.width), height: CGFloat(planeAnchor.planeExtent.height))
                node.geometry = plane
                node.eulerAngles.x = -.pi / 2
                applySurveyLineMaterial(to: node.geometry)
            }
        }

        private func applySurveyLineMaterial(to geometry: SCNGeometry?) {
            guard let material = geometry?.firstMaterial else { return }
            material.diffuse.contents = isFocusModeActive
                ? UIColor.systemYellow.withAlphaComponent(0.22)
                : UIColor.white.withAlphaComponent(0.16)
            material.emission.contents = isFocusModeActive
                ? UIColor.systemYellow.withAlphaComponent(0.10)
                : UIColor.white.withAlphaComponent(0.06)
            material.fillMode = .fill
            material.isDoubleSided = true
            material.readsFromDepthBuffer = true
            material.writesToDepthBuffer = false
        }

        private func focusMarkerNode() -> SCNNode {
            let geometry = SCNSphere(radius: 0.035)
            geometry.firstMaterial?.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.18)
            geometry.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.08)
            geometry.firstMaterial?.isDoubleSided = true

            let node = SCNNode(geometry: geometry)
            return node
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

            let position = SpatialPosition(
                x: Double(anchor.transform.columns.3.x),
                y: Double(anchor.transform.columns.3.y),
                z: Double(anchor.transform.columns.3.z)
            )
            let updated = LiveSpatialScanProgress(
                meshAnchorCount: meshAnchorIDs.count,
                planeAnchorCount: planeAnchorIDs.count,
                lastAnchorID: anchor.identifier.uuidString,
                lastKnownPosition: position,
                lastUpdatedAt: Date()
            )
            DispatchQueue.main.async {
                self.progress.wrappedValue = updated
            }
        }
    }
}

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
