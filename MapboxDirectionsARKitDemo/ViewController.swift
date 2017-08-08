import UIKit
import ARKit
import SceneKit
import SpriteKit
import CoreLocation

import MapboxARKit
import Mapbox
import MapboxDirections
import Turf

class ViewController: UIViewController {
    
    // Use this to control how ARKit aligns itself to the world
    // Often ARKit can determine the direction of North well enough for
    // the demo to work. However, its accuracy can be poor and it can
    // often make more sense to manually help the demo calibrate by starting
    // app while facing North. If you do that, change this setting to false
    var automaticallyFindTrueNorth = true
    
    @IBOutlet weak var cameraStateInfoLabel: UILabel!
    @IBOutlet weak var mapView: MGLMapView!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var controlsContainerView: UIView!
    
    // Create an instance of MapboxDirections to simplify querying the Mapbox Directions API
    let directions = Directions.shared
    var annotationManager: MapboxARAnnotationManager!
    
    // Define a shape collection that will be used to hold the point geometries that define the
    // directions routeline
    var waypointShapeCollectionFeature: MGLShapeCollectionFeature?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure and style control and map views
        styleControlViewContainer()
        configureMapboxMapView()
        
        // SceneKit boilerplate
        sceneView.delegate = self
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        sceneView.scene = SCNScene()
        
        // Create an AR annotation manager and give it a reference to the AR session
        annotationManager = MapboxARAnnotationManager(session: sceneView.session)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Start the AR session
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - Actions
    
    // Handle a long press on the Mapbox map view
    @IBAction func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        // Find the geographic coordinate of the point pressed in the map view
        let point = recognizer.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        
        // Remove any existing annotations on the map view
        if let existingAnnotations = mapView.annotations {
            mapView.removeAnnotations(existingAnnotations)
        }
        
        // Add an annotation to the map view for the pressed point
        let annotation = MGLPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        
        // When the gesture ends use the annotation location to initiate a query to the Mapbox Directions API
        if recognizer.state == .ended {
            
            // remove any previously rendered route
            annotationManager.removeAllARAnchors()
            resetShapeCollectionFeature(&waypointShapeCollectionFeature)
            self.updateSource(identifer: "annotationSource", shape: self.waypointShapeCollectionFeature)
            
            // Create a CLLocation instance to represent the end location for the directions query
            let annotationLocation = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
            queryDirections(with: annotationLocation)
        }
    }
    
    // MARK: - Directions
    
    // Query the directions endpoint with waypoints that are the current center location of the map
    // as the start and the passed in location as the end
    func queryDirections(with endLocation: CLLocation) {
        let currentLocation = CLLocation(latitude: self.mapView.centerCoordinate.latitude, longitude: self.mapView.centerCoordinate.longitude)
        
        let waypoints = [
            Waypoint(coordinate: CLLocationCoordinate2D(latitude: currentLocation.coordinate.latitude, longitude: currentLocation.coordinate.longitude), name: "start"),
            Waypoint(coordinate: CLLocationCoordinate2D(latitude: endLocation.coordinate.latitude, longitude: endLocation.coordinate.longitude), name: "end"),
            ]
        
        // Ask for walking directions
        let options = RouteOptions(waypoints: waypoints, profileIdentifier: .walking)
        options.includesSteps = true
        
        // Initiate the query
        let _ = directions.calculate(options) { (waypoints, routes, error) in
            guard error == nil else {
                print("Error calculating directions: \(error!)")
                return
            }
            
            // If a route is returned:
            if let route = routes?.first, let leg = route.legs.first {
                var polyline = [CLLocationCoordinate2D]()
                
                // Add an AR node and map view annotation for every defined "step" in the route
                for step in leg.steps {
                    let coordinate = step.coordinates!.first!
                    polyline.append(coordinate)
                    let stepLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    
                    // Update feature collection for map view
                    self.updateShapeCollectionFeature(&self.waypointShapeCollectionFeature, with: stepLocation, typeKey: "waypoint-type", typeAttribute: "big")
                    
                    // Add an AR node
                    self.annotationManager.addARAnnotation(startLocation: currentLocation, endLocation: stepLocation, calloutString: step.description)
                }
                
                let metersPerNode: CLLocationDistance = 5
                
                // Use Turf to find the total distance of the polyline
                let distance = Turf.distance(along: polyline)
                
                // Walk the route line and add a small AR node and map view annotation every metersPerNode
                for i in stride(from: 0, to: distance, by: metersPerNode) {
                    // Use Turf to find the coordinate of each incremented distance along the polyline
                    if let nextCoordinate = Turf.coordinate(at: i, fromStartOf: polyline) {
                        let interpolatedStepLocation = CLLocation(latitude: nextCoordinate.latitude, longitude: nextCoordinate.longitude)
                        
                        // Update feature collection for map view
                        self.updateShapeCollectionFeature(&self.waypointShapeCollectionFeature, with: interpolatedStepLocation, typeKey: "waypoint-type", typeAttribute: "small")
                        
                        // Add an AR node
                        self.annotationManager.addARAnnotation(startLocation: currentLocation, endLocation: interpolatedStepLocation, calloutString: nil)
                    }
                }
                
                // Update the source used for route line visualization with the latest waypoint shape collection
                self.updateSource(identifer: "annotationSource", shape: self.waypointShapeCollectionFeature)
            }
        }
        
        // Put the map view into a "follow with course" tracking mode
        mapView.userTrackingMode = .followWithCourse
    }
    
    // MARK: - Utility methods
    
    private func startSession() {
        // Create a session configuration
        let configuration = ARWorldTrackingSessionConfiguration()
        
        if automaticallyFindTrueNorth {
           configuration.worldAlignment = .gravityAndHeading
        } else {
            configuration.worldAlignment = .gravity
        }
        
        // Run the view's session
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    private func styleControlViewContainer() {
        let blurEffect = UIBlurEffect(style: .prominent)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = controlsContainerView.bounds
        blurView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        controlsContainerView.insertSubview(blurView, belowSubview: mapView)
    }
    
    private func configureMapboxMapView() {
        mapView.delegate = self
        mapView.styleURL = URL(string: "mapbox://styles/mapbox/cj3kbeqzo00022smj7akz3o1e") // "Moonlight" style
        mapView.userTrackingMode = .followWithHeading
        mapView.layer.cornerRadius = 10
    }
    
}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let mapboxAnchor = anchor as! MapboxARAnchor
        
        // Add a sphere node in AR for each anchor. Depending on if there is a callout string,
        // The node will have an image floating above it has a callout that provides additional
        // context to the user about what the node is intended to represent
        if mapboxAnchor.calloutString == nil {
            addSphereNode(to: node, for: mapboxAnchor)
        } else {
            addSphereNode(to: node, for: anchor, with: mapboxAnchor.calloutString!)
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        print("camera did change tracking state: \(camera.trackingState)")
        
        switch camera.trackingState {
        case .normal:
            cameraStateInfoLabel.text = "Ready!"
            UIView.animate(withDuration: 1, delay: 1, options: [], animations: {
                self.cameraStateInfoLabel.alpha = 0
            }, completion: nil)
        default:
            cameraStateInfoLabel.alpha = 1
            cameraStateInfoLabel.text = "Move the camera"
        }
    }
    
    // MARK: - Utility methods for ARSCNViewDelegate
    
    // Adds an SCNNode with a sphere geometry that loops through a color interpolation animation from green to blue
    func addSphereNode(to node: SCNNode, for anchor: MapboxARAnchor) {
        let sphereNode = createSphereNode(with: 0.2, firstColor: UIColor.green, secondColor: UIColor.blue)
        node.addChildNode(sphereNode)
    }
    
    func addSphereNode(to node: SCNNode, for anchor: ARAnchor, with description: String) {
        let firstColor = UIColor(colorLiteralRed: 0.0, green: 99/255.0, blue: 175/255.0, alpha: 1.0)
        let sphereNode = createSphereNode(with: 0.5, firstColor: firstColor, secondColor: UIColor.green)
        
        // Based on key strings in the directions' descriptions, add a billboard node to the sphere node
        // that contains an image for that step in the directions that will provide context to the user
        let lowerCasedDescription = description.lowercased()
        if lowerCasedDescription.contains("arrived") {
            createBillboardGeometry(with: "arrived", and: sphereNode)
        } else if lowerCasedDescription.contains("left") {
            createBillboardGeometry(with: "turnleft", and: sphereNode)
        } else if lowerCasedDescription.contains("right") {
            createBillboardGeometry(with: "turnright", and: sphereNode)
        } else if lowerCasedDescription.contains("head") {
            createBillboardGeometry(with: "straightahead", and: sphereNode)
        }
        
        node.addChildNode(sphereNode)
    }
    
    func createSphereNode(with radius: CGFloat, firstColor: UIColor, secondColor: UIColor) -> SCNNode {
        let geometry = SCNSphere(radius: radius)
        geometry.firstMaterial?.diffuse.contents = firstColor
        
        let sphereNode = SCNNode(geometry: geometry)
        sphereNode.animateInterpolatedColor(from: firstColor, to: secondColor, duration: 1)
        
        return sphereNode
    }
    
    func createBillboardGeometry(with iconNamed: String, and node: SCNNode) {
        let billboardGeometry = SCNPlane(width: 1.5, height: 1.5)
        billboardGeometry.cornerRadius = 0.1
        billboardGeometry.firstMaterial?.diffuse.contents = UIImage(named: iconNamed)
        
        let billBoardNode = SCNNode(geometry: billboardGeometry)
        var billboardPosition = node.position
        billboardPosition.y = 2.0
        billBoardNode.position = billboardPosition
        
        let constraint = SCNBillboardConstraint()
        billBoardNode.constraints = [constraint]
        
        node.addChildNode(billBoardNode)
    }
    
}

// MARK: - MGLMapViewDelegate

extension ViewController: MGLMapViewDelegate {
    
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        // Set up Mapbox iOS Maps SDK "runtime styling" source and style layers to style the directions route line
        waypointShapeCollectionFeature = MGLShapeCollectionFeature()
        let annotationSource = MGLShapeSource(identifier: "annotationSource", shape: waypointShapeCollectionFeature, options: nil)
        mapView.style?.addSource(annotationSource)
        let circleStyleLayer = MGLCircleStyleLayer(identifier: "circleStyleLayer", source: annotationSource)
        
        let color = UIColor(colorLiteralRed: 147/255.0, green: 230/255.0, blue: 249/255.0, alpha: 1.0)
        let colorStops = ["small": MGLStyleValue<UIColor>(rawValue: color.withAlphaComponent(0.75)),
                          "big": MGLStyleValue<UIColor>(rawValue: color)]
        circleStyleLayer.circleColor = MGLStyleValue(
            interpolationMode: .categorical,
            sourceStops: colorStops,
            attributeName: "waypoint-type",
            options: nil
        )
        let sizeStops = ["small": MGLStyleValue<NSNumber>(rawValue: 2),
                         "big": MGLStyleValue<NSNumber>(rawValue: 4)]
        circleStyleLayer.circleRadius = MGLStyleValue(
            interpolationMode: .categorical,
            sourceStops: sizeStops,
            attributeName: "waypoint-type",
            options: nil
        )
        mapView.style?.addLayer(circleStyleLayer)
    }
    
    func generateFeature(centerCoordinate: CLLocationCoordinate2D) -> MGLPointFeature {
        let feature = MGLPointFeature()
        feature.coordinate = centerCoordinate
        return feature
    }
    
    // MARK: - Utility methods for MGLMapViewDelegate
    
    private func updateSource(identifer: String, shape: MGLShape?) {
        guard let shape = shape else {
            return
        }
        
        if let source = mapView.style?.source(withIdentifier: identifer) as? MGLShapeSource {
            source.shape = shape
        }
    }
    
    private func updateShapeCollectionFeature(_ feature: inout MGLShapeCollectionFeature?, with location: CLLocation, typeKey: String?, typeAttribute: String?) {
        if let shapeCollectionFeature = feature {
            let annotation = MGLPointFeature()
            if let key = typeKey, let value = typeAttribute {
                annotation.attributes = [key: value]
            }
            annotation.coordinate = location.coordinate
            let newFeatures = [annotation].map { $0 as MGLShape }
            let existingFeatures: [MGLShape] = shapeCollectionFeature.shapes
            let allFeatures = newFeatures + existingFeatures
            feature = MGLShapeCollectionFeature(shapes: allFeatures)
        }
    }
    
    private func resetShapeCollectionFeature(_ feature: inout MGLShapeCollectionFeature?) {
        if feature != nil {
            feature = MGLShapeCollectionFeature(shapes: [])
        }
    }
    
}

extension SCNNode {
    
    func animateInterpolatedColor(from oldColor: UIColor, to newColor: UIColor, duration: Double) {
        let act0 = SCNAction.customAction(duration: duration, action: { (node, elapsedTime) in
            let percentage = elapsedTime / CGFloat(duration)
            self.geometry?.firstMaterial?.diffuse.contents = newColor.interpolatedColor(to: oldColor, percentage: percentage)
        })
        let act1 = SCNAction.customAction(duration: duration, action: { (node, elapsedTime) in
            let percentage = elapsedTime / CGFloat(duration)
            self.geometry?.firstMaterial?.diffuse.contents = oldColor.interpolatedColor(to: newColor, percentage: percentage)
        })
        
        let act = SCNAction.repeatForever(SCNAction.sequence([act0, act1]))
        self.runAction(act)
    }
    
}

extension UIColor {
    
    // https://stackoverflow.com/questions/40472524/how-to-add-animations-to-change-sncnodes-color-scenekit
    func interpolatedColor(to: UIColor, percentage: CGFloat) -> UIColor {
        let fromComponents = self.cgColor.components!
        let toComponents = to.cgColor.components!
        let color = UIColor(red: fromComponents[0] + (toComponents[0] - fromComponents[0]) * percentage,
                            green: fromComponents[1] + (toComponents[1] - fromComponents[1]) * percentage,
                            blue: fromComponents[2] + (toComponents[2] - fromComponents[2]) * percentage,
                            alpha: fromComponents[3] + (toComponents[3] - fromComponents[3]) * percentage)
        return color
    }
    
}
