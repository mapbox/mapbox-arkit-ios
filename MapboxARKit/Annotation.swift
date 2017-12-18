import CoreLocation

public class Annotation: NSObject {
    
    public var location: CLLocation
    public var calloutImage: UIImage?
    public var anchor: MBARAnchor?
    public var identifier: String
    public init(location: CLLocation, calloutImage: UIImage?, identifier: String) {
        self.location = location
        self.calloutImage = calloutImage
        self.identifier = identifier
    }
    
}
