import ARKit
import SpriteKit
import CoreLocation

@objc public protocol AnnotationManagerDelegate {
    
    @objc optional func node(for annotation: Annotation) -> SCNNode?
    @objc optional func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera)
    
}

public class AnnotationManager: NSObject {
    
    private(set) var session: ARSession
    private(set) var sceneView: ARSCNView?
    
    private(set) var anchors = [ARAnchor]()
    private(set) var annotationsByAnchor = [ARAnchor: Annotation]()
    
    
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
    
    public func addAnnotation(annotation: Annotation) {
        guard let originLocation = originLocation else {
            print("Warning: \(type(of: self)).\(#function) was called without first setting \(type(of: self)).originLocation")
            return
        }
        
        // Create a Mapbox AR anchor anchor at the transformed position
        let anchor = MBARAnchor(originLocation: originLocation, location: annotation.location)
        
        // Add the anchor to the session
        session.add(anchor: anchor)
        
        anchors.append(anchor)
        annotationsByAnchor[anchor] = annotation
    }
    
    public func removeAllAnnotations() {
        for anchor in anchors {
            session.remove(anchor: anchor)
        }
        
        anchors.removeAll()
        annotationsByAnchor.removeAll()
    }
    
}

// MARK: - ARSCNViewDelegate

extension AnnotationManager: ARSCNViewDelegate {
    
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        delegate?.session?(session, cameraDidChangeTrackingState: camera)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        // Handle MBARAnchor
        if let anchor = anchor as? MBARAnchor {
            let annotation = annotationsByAnchor[anchor]!
            
            var newNode: SCNNode!
            
            // If the delegate supplied a node then use that, otherwise provide a basic default node
            if let suppliedNode = delegate?.node?(for: annotation) {
                newNode = suppliedNode
            } else {
                newNode = createDefaultNode()
            }
                        
            if let calloutImage = annotation.calloutImage {
                let calloutNode = createCalloutNode(with: calloutImage, node: newNode)
                newNode.addChildNode(calloutNode)
            }
            
            node.addChildNode(newNode)
        }
        
        // TODO: let delegate provide a node for a non-MBARAnchor
    }
    
    // MARK: - Utility methods for ARSCNViewDelegate
    
    func createDefaultNode() -> SCNNode {
        let geometry = SCNSphere(radius: 0.2)
        geometry.firstMaterial?.diffuse.contents = UIColor.red
        return SCNNode(geometry: geometry)
    }
    
    func createCalloutNode(with image: UIImage, node: SCNNode) -> SCNNode {
        let calloutGeometry = SCNPlane(width: 1.5, height: 1.5)
        calloutGeometry.cornerRadius = 0.1
        calloutGeometry.firstMaterial?.diffuse.contents = image
        
        let calloutNode = SCNNode(geometry: calloutGeometry)
        var nodePosition = node.position
        nodePosition.y = 2.0
        calloutNode.position = nodePosition
        
        let constraint = SCNBillboardConstraint()
        calloutNode.constraints = [constraint]
        
        return calloutNode 
    }
    
}
