import ARKit
import SpriteKit
import CoreLocation

@objc public protocol AnnotationManagerDelegate {
    
    @objc optional func node(for annotation: Annotation) -> SCNNode?
    @objc optional func scaleNode(node: SCNNode, location: CLLocation) -> SCNNode?
    @objc optional func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera)
    
}

open class AnnotationManager: NSObject {
    
    public private(set) var session: ARSession
    public private(set) var sceneView: ARSCNView?
    public private(set) var anchors = [ARAnchor]()
    public private(set) var annotationsByAnchor = [ARAnchor: Annotation]()
    public private(set) var annotationsByNode = [SCNNode: Annotation]()
    public var delegate: AnnotationManagerDelegate?
    public var originLocation: CLLocation?
    private var nodesAddedDirectlyByAnchor: [ARAnchor: SCNNode] = [:]
    
    public init(session: ARSession) {
        self.session = session
    }
    
    convenience public init(sceneView: ARSCNView) {
        self.init(session: sceneView.session)
        session = sceneView.session
        self.sceneView = sceneView
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
        annotation.anchor = anchor
        annotationsByAnchor[anchor] = annotation
    }
    
    public func addAnnotations(annotations: [Annotation]) {
        for annotation in annotations {
            addAnnotation(annotation: annotation)
        }
    }

    private func removeNodeReference() {
        for node in annotationsByNode.keys {
            node.enumerateHierarchy({ (node, _) in
                node.removeFromParentNode()
            })
        }
        annotationsByNode.removeAll()
        sceneView?.scene.rootNode.enumerateChildNodes({ (node, _) in
            node.removeFromParentNode()
            node.enumerateHierarchy({ (node, _) in
                node.removeFromParentNode()
            })
        })
    }
    
    public func removeAllAnnotations() {
        removeNodeReference()
        
        for anchor in anchors {
            session.remove(anchor: anchor)
        }
        anchors.removeAll()
        annotationsByAnchor.removeAll()
    }
    
    public func removeAnnotations(annotations: [Annotation]) {
        removeNodeReference()
        
        for annotation in annotations {
            removeAnnotation(annotation: annotation)
        }
    }
    
    public func removeAnnotation(annotation: Annotation) {
        if let anchor = annotation.anchor {
            session.remove(anchor: anchor)
            anchors.remove(at: anchors.index(of: anchor)!)
            annotationsByAnchor.removeValue(forKey: anchor)
        }
    }
    
    public func hideAllNodes(isHidden: Bool) {
        for node in annotationsByNode.keys {
            node.isHidden = isHidden
        }
    }
    
    open func addNode(newNode: SCNNode, annotation: Annotation) {
        
        if let calloutImage = annotation.calloutImage {
            let calloutNode = createCalloutNode(with: calloutImage, node: newNode)
            newNode.addChildNode(calloutNode)
        }
    }
    
    public func addNodeDirectly(nodeToAdd: SCNNode, anchor: ARAnchor) {
        nodesAddedDirectlyByAnchor[anchor] = nodeToAdd
        session.add(anchor: anchor)
    }
    
    public func removeDirectlyAddedNodes() {
        for (key, _) in nodesAddedDirectlyByAnchor {
            session.remove(anchor: key)
        }
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
            guard let annotation = annotationsByAnchor[anchor] else {
                print("[MapboxARKit.AnnotationManager.renderer didAdd node:] Cannot render node :: annotationsByAnchor[anchor] is nil")
                return
            }
            
            var newNode: SCNNode!
            
            // If the delegate supplied a node then use that, otherwise provide a basic default node
            if let suppliedNode = delegate?.node?(for: annotation) {
                newNode = suppliedNode
            } else {
                newNode = createDefaultNode()
            }
            
            addNode(newNode: newNode, annotation: annotation)
            
            let scaledNode = delegate?.scaleNode?(node: newNode, location: annotation.location)
            if scaledNode != nil {
                newNode = scaledNode
            }
            
            node.addChildNode(newNode)

            annotationsByNode[newNode] = annotation
        } else {
            if nodesAddedDirectlyByAnchor.isEmpty == false && nodesAddedDirectlyByAnchor[anchor] != nil {
                node.addChildNode(nodesAddedDirectlyByAnchor[anchor]!)
            }
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
        
        var width: CGFloat = 0.0
        var height: CGFloat = 0.0
        
        if image.size.width >= image.size.height {
            width = image.size.width / image.size.height
            height = 1.0
        } else {
            width = 1.0
            height = image.size.height / image.size.width
        }
        
        let calloutGeometry = SCNPlane(width: width, height: height)
        calloutGeometry.firstMaterial?.diffuse.contents = image
        
        let calloutNode = SCNNode(geometry: calloutGeometry)
        var nodePosition = node.position
        let (min, max) = node.boundingBox
        let nodeHeight = max.y - min.y
        nodePosition.y = nodeHeight + 0.5
        
        calloutNode.position = nodePosition
        
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = [.Y]
        calloutNode.constraints = [constraint]
        
        return calloutNode
    }
    
}
