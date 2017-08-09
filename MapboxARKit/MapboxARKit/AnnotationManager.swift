import ARKit
import SpriteKit
import CoreLocation
import GLKit

// A preview of an API for abstracting the notion of annotations and GeoJSON for use in AR

public class AnnotationManager {
    
    private(set) var anchors = [ARAnchor]()
    private var session: ARSession
    private var sceneView: ARSCNView?
    
    public var originLocation: CLLocation?
    
    public init(session: ARSession) {
        self.session = session
    }
    
    convenience public init(sceneView: ARSCNView) {
        self.init(session: sceneView.session)
        session = sceneView.session
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
