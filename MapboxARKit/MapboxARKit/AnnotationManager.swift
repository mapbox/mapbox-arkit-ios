import ARKit
import SpriteKit
import CoreLocation
import GLKit

// A preview of an API for abstracting the notion of annotations and GeoJSON for use in AR

public class AnnotationManager {
    
    private(set) var anchors = [ARAnchor]()
    private var session: ARSession
    private var sceneView: ARSCNView?
    
    public init(session: ARSession) {
        self.session = session
    }
    
    convenience public init(sceneView: ARSCNView) {
        self.init(session: sceneView.session)
        session = sceneView.session
    }
    
    public func addARAnnotation(startLocation: CLLocation, endLocation: CLLocation, calloutString: String?) {
        // Create a Mapbox AR anchor anchor at the transformed position
        let anchor = MBARAnchor(originLocation: startLocation, location: endLocation)
        
        // Set the callout string (if any) on the anchor
        anchor.calloutString = calloutString
        
        // Add the anchor to the session
        session.add(anchor: anchor)
        anchors.append(anchor)
    }
    
    public func removeAllARAnchors() {
        for anchor in anchors {
            session.remove(anchor: anchor)
        }
        anchors.removeAll()
    }
    
}
