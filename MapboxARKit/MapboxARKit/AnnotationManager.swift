import ARKit
import SpriteKit
import CoreLocation
import GLKit

@objc public protocol AnnotationManagerDelegate {
    
    @objc optional func node(for anchor: MBARAnchor) -> SCNNode?
    @objc optional func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera)
    
}

public class AnnotationManager: NSObject {
    
    private(set) var session: ARSession
    private(set) var sceneView: ARSCNView?
    private(set) var anchors = [ARAnchor]()
    public var delegate: AnnotationManagerDelegate?
    public var originLocation: CLLocation?
    
    public init(session: ARSession) {
        self.session = session
    }
    
    convenience public init(sceneView: ARSCNView) {
        self.init(session: sceneView.session)
        session = sceneView.session
        sceneView.delegate = self
    }
    
    public func addAnnotation(location: CLLocation, calloutString: String?) {
        guard let originLocation = originLocation else {
            print("Warning: \(type(of: self)).\(#function) was called without first setting \(type(of: self)).originLocation")
            return
        }
        
        // Create a Mapbox AR anchor anchor at the transformed position
        let anchor = MBARAnchor(originLocation: originLocation, location: location)
        
        // Set the callout string (if any) on the anchor
        anchor.calloutString = calloutString
        
        // Add the anchor to the session
        session.add(anchor: anchor)
        anchors.append(anchor)
    }
    
    public func removeAllAnnotations() {
        for anchor in anchors {
            session.remove(anchor: anchor)
        }
        anchors.removeAll()
    }
    
}

// MARK: - ARSCNViewDelegate

extension AnnotationManager: ARSCNViewDelegate {
    
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        delegate?.session?(session, cameraDidChangeTrackingState: camera)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let anchor = anchor as? MBARAnchor {
            // If the delegate supplied a node then use that, otherwise provide a basic default node
            if let suppliedNode = delegate?.node?(for: anchor) {
                node.addChildNode(suppliedNode)
            } else {
                let defaultNode = createDefaultNode()
                node.addChildNode(defaultNode)
            }
        }            
    }
    
    // MARK: - Utility methods for ARSCNViewDelegate
    
    func createDefaultNode() -> SCNNode {
        let geometry = SCNSphere(radius: 0.2)
        geometry.firstMaterial?.diffuse.contents = UIColor.red
        return SCNNode(geometry: geometry)
    }
    
}
