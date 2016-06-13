//
//  ViewController.swift
//  CaptureFlagProject
//
//  Created by Vu Dinh and Michael Arbogast on 5/23/16.
//  Copyright © 2016 Vu Dinh. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase
import FirebaseAuth
import FirebaseDatabase
import FBSDKCoreKit
import AVFoundation

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var startGameOutlet: UIBarButtonItem!
    @IBOutlet weak var redoButtonOutlet: UIBarButtonItem!
    
    
    @IBOutlet weak var mapView: MKMapView!
    
    let ref = FIRDatabase.database().reference()
    
    let chirpSound: SystemSoundID = 1016
    let fanfare: SystemSoundID = 1325
    let alarmSound: SystemSoundID = 1304
    
    var onBlueTeam = true
    var isGameCreator = false
    var game_is_active = false
    var inBlueArea = false
    var blueFlagLocation = [String: AnyObject]()
    var greenFlagLocation = [String: AnyObject]()
    var currentUser: AnyObject?
    var bluegreen = "blue"
    var playersToDisplay = [String:AnyObject]()
    var otherPlayers: AnyObject? //remove eventually
    var boundaryArray =  [CLLocationCoordinate2D]()
    var boundaryDict = [[String: AnyObject]]()
    var blueBoundaryArray = [CLLocationCoordinate2D]()
    var greenBoundaryArray = [CLLocationCoordinate2D]()
    var mapZoomCounter : Bool = false
    let locationManager = CLLocationManager()
    var playerNumber : Int = 0
    
    var region: MKCoordinateRegion?
    
    override func viewDidLoad() {
        //set up location manager
        
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization() //only use when app in use
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest //want user exact location
//        self.locationManager.allowsBackgroundLocationUpdates = true
        self.locationManager.startUpdatingLocation()
        self.mapView.showsUserLocation = true
        mapView.delegate = self
        
        super.viewDidLoad()
        
//        SET BARBUTTON TO EITHER READY OR START GAME
        if isGameCreator == false {
            startGameOutlet.title = "Ready"
        }
        if isGameCreator == true {
            startGameOutlet.enabled = false
        }
        
        //touch reaction
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(_:)))
        gestureRecognizer.delegate = self
        mapView.addGestureRecognizer(gestureRecognizer)
        
        //MAKE ACTIVE IN DB
        if let user = FIRAuth.auth()?.currentUser {
            let thisUser = self.ref.child("users/\(user.uid)")
                thisUser.updateChildValues(["is_active": "true"])
                currentUser = user
            
        }

        
        //ACTIVE TO FALSE ON DISCONNECT
        ref.child("users/\(currentUser!.uid)/is_active").onDisconnectSetValue("false")
        ref.child("users/\(currentUser!.uid)/is_ready").onDisconnectSetValue("false")
        ref.child("users/\(currentUser!.uid)/number").onDisconnectSetValue(0)

        ref.child("users/\(currentUser!.uid)/location/lat").onDisconnectSetValue("false")
        ref.child("users/\(currentUser!.uid)/location/long").onDisconnectSetValue("false")
        
        
        
        //UPDATE USER POSITIONS FROM DATABASE ON CHANGE
        ref.observeEventType(.Value, withBlock: {
            snapshot in
//            print("\(snapshot.key) -> \(snapshot.value)")
            let players = snapshot.value
            self.otherPlayers = players!["users"] as! NSDictionary
//            print(self.otherPlayers!)
//            print(self.otherPlayers!.count)
            if self.otherPlayers!.count > 0 {
                for (userid, value) in self.otherPlayers as! NSDictionary {
//                    print(value["first_name"], value["location"])
                    if self.currentUser!.uid != userid as? String {
                        if value["is_active"] as? String == "true" {
                            self.playersToDisplay["\(userid)"] = value
                            
                        } else {
                            self.playersToDisplay.removeValueForKey("\(userid)")
//                            print(self.playersToDisplay)
                        }
                    }
    //                print(self.playersToDisplay)
                    
                if value["long"] != nil {
                    self.addAnnotationForOtherUser()
                }
                self.amINearSomeoneElse()
                }
            }
            
        })
        
        
//////////DISABLE REDO BUTTON IF NOT CREATOR //////////////////////////
        if isGameCreator == false {
            redoButtonOutlet.title = " "
            redoButtonOutlet.enabled = false
        }
        
        //DISABLE READY BUTTON IF GAME AREA NOT SET
//        if blueFlagLocation.count < 1 {
//            startGameOutlet.enabled = false
//        }
        
    }
    
    //CLEAR BOUNDARY PINS
    @IBAction func redoButtonPressed(sender: UIBarButtonItem) {
        for overlay in self.mapView.overlays {
            self.mapView.removeOverlay(overlay)
        }
        self.bluegreen = "blue"
        blueBoundaryArray = []
        greenBoundaryArray = []
        boundaryArray = []
        blueFlagLocation = [:]
        greenFlagLocation = [:]
        
        playersToDisplay = [:]
        boundaryDict = []
        addBoundary()
        var annotationsToRemove = [MKAnnotation]()
        for annotation in self.mapView.annotations {
            if annotation.title!! == "boundary" {
                annotationsToRemove.append(annotation)
            }
            if annotation.title!! == "blue_flag" {
                annotationsToRemove.append(annotation)
            }
            if annotation.title!! == "green_flag" {
                annotationsToRemove.append(annotation)
            }
        }
        self.mapView.removeAnnotations(annotationsToRemove)
        
    }
    
    
    //DROP PIN FOR BOUNDARY
    func handleTap(gestureRecon: UILongPressGestureRecognizer) {
        if isGameCreator == true {
            if boundaryArray.count < 4 {
                let location = gestureRecon.locationInView(mapView)
                let coordinate = mapView.convertPoint(location, toCoordinateFromView: mapView)
                if boundaryArray.count == 0 {
                    blueBoundaryArray.append(coordinate)
                    greenBoundaryArray.append(coordinate)
                }
                if boundaryArray.count == 1 {
                    blueBoundaryArray.append(coordinate)
                }
                if boundaryArray.count == 2{
                    greenBoundaryArray.append(coordinate)
                    blueBoundaryArray.append(coordinate)
                }
                if boundaryArray.count == 3 {
                    greenBoundaryArray.append(coordinate)
                }
                boundaryDict.append(["lat": coordinate.latitude, "long": coordinate.longitude])
                boundaryArray.append(coordinate)
                //add annotation
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = "boundary"
                mapView.addAnnotation(annotation)
            }
            
            addBoundary()
        }
    }
    
    //ADD ALL BOUNDARIES WHICH HAVE JUST BEEN RETRIEVED
    func addAllBoundaries() {
        for bound in 0..<boundaryArray.count {
            if bound == 0 {
                blueBoundaryArray.append(boundaryArray[bound])
                greenBoundaryArray.append(boundaryArray[bound])
            }
            if bound == 1 {
                blueBoundaryArray.append(boundaryArray[bound])
            }
            if bound == 2{
                greenBoundaryArray.append(boundaryArray[bound])
                blueBoundaryArray.append(boundaryArray[bound])
            }
            if bound == 3 {
                greenBoundaryArray.append(boundaryArray[bound])
            }
        }
        
        addBoundary()
        
    }
    
    //ADD POINT TO BOUNDARY ARRAY
    func addBoundary() {
//        print("adding boundary")
        mapView.removeOverlays(mapView.overlays)
        if boundaryArray.count > 2 {
            let polygon = MKPolygon(coordinates: &boundaryArray, count: boundaryArray.count)
            let bluePolygon = MKPolygon(coordinates: &blueBoundaryArray, count: blueBoundaryArray.count)
            let greenPolygon = MKPolygon(coordinates: &greenBoundaryArray, count: greenBoundaryArray.count)
            self.bluegreen = "blue"
            mapView.addOverlay(bluePolygon)
            self.bluegreen = "green"
            mapView.addOverlay(greenPolygon)
            self.bluegreen = "red"
            mapView.addOverlay(polygon)
        }
        if boundaryArray.count == 4 {
            startGameOutlet.enabled = true
        }
    }
    
    //RENDER BOUNDARY OVERLAYS
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
//        print("in overlay renderer")
        let polygonView = MKPolygonRenderer(overlay: overlay)
        switch bluegreen {
        case "blue":
            polygonView.alpha = 0.2
            polygonView.fillColor = UIColor.blueColor()
            return polygonView
        case "green":
            polygonView.alpha = 0.2
            polygonView.fillColor = UIColor.greenColor()
            return polygonView
        default:
            polygonView.strokeColor = UIColor.redColor()
            polygonView.lineWidth = 0.5
            polygonView.alpha = 0.83
//            polygonView.fillColor = UIColor.blueColor()
            return polygonView
        }
    }
    
//    func mapView(mapView: MKMapView, didAddOverlayRenderers renderers: [MKOverlayRenderer]) {
//        if MKMapRectIntersectsRect(<#T##rect1: MKMapRect##MKMapRect#>, <#T##rect2: MKMapRect##MKMapRect#>)
//    }
    
    //UPDATE ANNOTATIONS FOR OTHER USERS
    func addAnnotationForOtherUser() {
//        print("annotations func")
        if otherPlayers!.count > 0 {
            for (key, val) in playersToDisplay {
                for annotation in mapView.annotations {
//                    print(annotation.title, val["first_name"], "this is the update annotations loop per annotation")
                    if val["first_name"] != nil && annotation.title != nil {

                        if annotation.title! == "\(val["first_name"])" {
                            mapView.removeAnnotation(annotation)
                        }
//                        print("annotation coord", annotation.coordinate)
                        if annotation.subtitle != nil {
                            if annotation.subtitle! == "\(val["number"]!!)" {
                                mapView.removeAnnotation(annotation)
                            }
                            if annotation.subtitle! == "0" {
                                mapView.removeAnnotation(annotation)
                            }
                        }
                    }
                    
                }
                let latVal = (playersToDisplay[key]!["location"]?!["lat"] as! NSString).doubleValue
                debugPrint(latVal)
                let longVal = (playersToDisplay[key]!["location"]?!["long"] as! NSString).doubleValue
                let otherCoord = CLLocationCoordinate2DMake(latVal, longVal)
                
                let dropPin = MKPointAnnotation()
                
                dropPin.coordinate = otherCoord
                dropPin.title = "\(val["first_name"]!!)"
                dropPin.subtitle = "\(val["number"]!!)"
                mapView.addAnnotation(dropPin)
                
       //CHECK IF OUT OF BOUNDS
                if game_is_active == true {
                    if self.userInsideGreenPolygon((self.region?.center)!) == true {
                        print("you're green")
                    } else {
                        if self.userInsidePolygon((self.region?.center)!) == false {
                            print("you're out of bounds, buster!")
                            AudioServicesPlayAlertSound(chirpSound)
                        } else {
                            print("you're blue")
                        }
                    }
                }

            }
        }
    }
    
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if !(annotation is MKPointAnnotation) {
//            print("heyo")
            return nil
        }
        
        let reuseId = "test"
        if annotation.title! == "blue_flag" {
            var anView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId)
            if anView == nil {
                anView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                anView!.image = UIImage(named:"flag1")
                let size = CGSize(width: 20, height: 20)
                UIGraphicsBeginImageContext(size)
                anView!.drawViewHierarchyInRect(CGRectMake(0, 0, size.width, size.height), afterScreenUpdates: true)
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                anView!.image = resizedImage
                anView!.canShowCallout = true
            } else {
                anView!.annotation = annotation
            }
            return anView
        } else if annotation.title! == "green_flag" {
            var anView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId)
            if anView == nil {
                anView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                anView!.image = UIImage(named:"flag1")
                let size = CGSize(width: 20, height: 20)
                UIGraphicsBeginImageContext(size)
                anView!.drawViewHierarchyInRect(CGRectMake(0, 0, size.width, size.height), afterScreenUpdates: true)
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                anView!.image = resizedImage
                anView!.canShowCallout = true
            } else {
                anView!.annotation = annotation
            }
            return anView
        } else if annotation.title! == "boundary" {
            var anView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId)
            if anView == nil {
                anView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                anView!.image = UIImage(named:"blue")
                anView!.canShowCallout = true
            } else {
                anView!.annotation = annotation
            }
            return anView
        } else if annotation.subtitle != nil {
            var anView = mapView.dequeueReusableAnnotationViewWithIdentifier("player")
            if anView == nil {
                anView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                anView!.image = UIImage(named:"redperson")
                anView!.canShowCallout = true
            } else {
                anView!.annotation = annotation
            }
            return anView
        }
        return nil
    }
    
    
    
    //DID UPDATE LOCATIONS
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last //want most current loc
        let center = CLLocationCoordinate2D(latitude: location!.coordinate.latitude, longitude: location!.coordinate.longitude)
        
//        print("Center ", center)
        let initialRegion = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        
        region = initialRegion
//        print(region)
        if mapZoomCounter == false {
            self.mapView.setRegion(initialRegion, animated: true) ////THIS ZOOMS US IN TO OUR LOCATION
            mapZoomCounter = true
        }
//        self.locationManager.stopUpdatingLocation() ///THIS STOPS UPDATING OUR LOCATION
        
//        print(FIRAuth.auth()?.currentUser?.uid, region?.center)
        
        //update location to database
        if let user = FIRAuth.auth()?.currentUser {
            //            print(user.displayName)

        let thisUser = self.ref.child("users/\(user.uid)/location")
            thisUser.updateChildValues(["lat" : "\(self.region!.center.latitude)"])
            thisUser.updateChildValues(["long" : "\(self.region!.center.longitude)"])
        }
        if game_is_active == true {
            if self.userInsideGreenPolygon((self.region?.center)!) == true {
                print("you're green")
            } else {
                if self.userInsidePolygon((self.region?.center)!) == false {
                    print("you're out of bounds, buster!")
                    AudioServicesPlayAlertSound(chirpSound)
                } else {
                    print("you're blue")
                }
            }
        }
    }

    func locationManager(manager:CLLocationManager, didFailWithError error: NSError) {
        print("Errors: " + error.localizedDescription)
    }
    
 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////START BUTTON PRESSED
    @IBAction func selectMapBarButtonPressed(sender: UIBarButtonItem){
        
        // DISABLE REDO BUTTON
        redoButtonOutlet.enabled = false
        startGameOutlet.enabled = false

        if isGameCreator == true {
            for (userid, value) in self.otherPlayers as! NSDictionary {
//                print(value["first_name"], value["location"])
                //                print(self.playersToDisplay)
                self.addAnnotationForOtherUser()
                game_is_active = true
                sender.enabled = false //DISABLES BUTTON
            }
//                print(boundaryArray, "\n",blueBoundaryArray, "\n", greenBoundaryArray)
//                print(userInsidePolygon(region!.center), region!.center.latitude, region!.center.longitude)
//                print(blueBoundaryArray)
                addFlag1()
                addFlag2()
            
            //ALSO PUSH TO DATABASE
            if let user = FIRAuth.auth()?.currentUser {
                let thisGame = self.ref.child("games/1/")
                thisGame.updateChildValues(["boundaries": boundaryDict])
                thisGame.updateChildValues(["blue_flag": blueFlagLocation, "green_flag": greenFlagLocation])
                
//                print(thisGame, "thisGame pringitnginsg")
                
                
                let thisUser = self.ref.child("users/\(user.uid)")
                thisUser.updateChildValues(["is_ready": "true"])

                self.playerNumber = playerNumber + 1

                thisUser.updateChildValues(["number" : playerNumber])
                
//                startGameOutlet.enabled = false
                
                //ALERT TO LET CREATOR KNOW THEY CREATED A GAME
                let alertController = UIAlertController(title: "Capture", message:
                    "You've created a game. Good Luck", preferredStyle: UIAlertControllerStyle.Alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
                
                self.presentViewController(alertController, animated: true, completion: nil)
            }

        } else {
            
            //DISABLE READY BUTTON AFTER CLICKED
//            startGameOutlet.enabled = false

//        if isGameCreator == false
            if let user = FIRAuth.auth()?.currentUser {
                let thisUser = self.ref.child("users/\(user.uid)")
                thisUser.updateChildValues(["is_ready": "true"])
                
              
                
                thisUser.updateChildValues(["number" : playerNumber])
                
                
//                self.boundaryArray
                let boundsUrl = self.ref.child("games/1/boundaries/")
                boundsUrl.observeSingleEventOfType(.Value, withBlock: { snapshot in
                    let bounds = snapshot.value as! NSArray
                    for i in 0..<bounds.count {
//                        print("bounds[i]", bounds[i])
                        let tempLat = bounds[i]["lat"] as! CLLocationDegrees
                        let tempLong = bounds[i]["long"] as! CLLocationDegrees
                        let tempPin = CLLocationCoordinate2DMake(tempLat, tempLong)
                        self.boundaryArray.append(tempPin)
//                        print(self.boundaryArray)
                    }
                    self.addAllBoundaries()
                })
                
                var flagUrl = boundsUrl

                
                //update player number
                let player_number_db = self.ref.child("users/")
                player_number_db.observeSingleEventOfType(.Value, withBlock: { snapshot in
                    let player_numb = snapshot.value as! NSDictionary
                    for (key,val) in player_numb{
//                        print(val["number"], "VALALALALKJASLKDJASLDAJLDSJLKDADJ")
                        if self.playerNumber < val["number"] as! Int {
                            self.playerNumber = val["number"] as! Int
//                        }

//                    }
//                    print("GETTING ALL THE UERSERSFLSDJFDLFJSDLFJSDFL SDJFLKSDJF", snapshot)
//                    })
//        determine if user number modulo 2 is green team or blue team

//                ref.observeSingleEventOfType(.Value, withBlock: { snapshot in
//                    let current_user = snapshot.value
//                    let my_user = current_user!["users"] as! NSDictionary
////                    let user_number = current_user.playerNumber
//                    if my_user.count > 0 {
//                        for (key, value) in my_user {
//                        print("MY NUMBERRRRRRR", value["number"]!)
                
//                    let my_user_number = value["number"]! as! Int
                
//                    self.playerNumber = value["number"] as! Int
//                    print(self.playerNumber, "playernumber")
                    self.playerNumber += 1
                    
                    thisUser.updateChildValues(["number": self.playerNumber])
                            
                            
                if (self.playerNumber > 0 && self.playerNumber % 2 != 0) {
    //                    if self.onBlueTeam {
                       flagUrl = self.ref.child("games/1/green_flag")
                    } else {
                       flagUrl = self.ref.child("games/1/blue_flag")
                    }
                                
                    //print target team flag
                    flagUrl.observeSingleEventOfType(.Value, withBlock: { snapshot in
//                        print("FLAG AHOY", snapshot)
                        let flagDictionary = snapshot.value as! NSDictionary
                        let tempLat = (flagDictionary["lat"] as! NSString).doubleValue
                        let tempLong = (flagDictionary["long"] as! NSString).doubleValue
                        
                        let tempFlag = CLLocationCoordinate2DMake(tempLat, tempLong)
                        self.greenFlagLocation = ["lat": tempLat, "long": tempLong]
                        
                        //AND PIN IT TO THE MAP
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = tempFlag
                        if self.onBlueTeam == true {
                            annotation.title = "green_flag"
                        } else {
                            annotation.title = "blue_flag"
                        }
                        self.mapView.addAnnotation(annotation)
//                        print(self.greenFlagLocation, "flagLocation")
                        self.startGameOutlet.enabled = false
                        
                        
                        
                        
                    })
                }}
            })
               self.startGameOutlet.enabled = false
                
                let alertController = UIAlertController(title: "Capture", message:
                    "Good Luck", preferredStyle: UIAlertControllerStyle.Alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
                
                self.presentViewController(alertController, animated: true, completion: nil)
            }
        }
    }
    
    // // // // // // // // // // // // //
    
    //ADD FLAG
    func addFlag1() {
        let blueFlagCoord = boundaryArray[1]
        let blueFlagLatitudeRandom = blueFlagCoord.latitude - (Double(arc4random_uniform(20)) / 10000) + (Double(arc4random_uniform(20)) / 10000)
        let blueFlagLongitudeRandom =  blueFlagCoord.longitude - (Double(arc4random_uniform(20)) / 10000) + (Double(arc4random_uniform(20)) / 10000)
        let randomBlueFlagCoord = CLLocationCoordinate2D(latitude: blueFlagLatitudeRandom, longitude: blueFlagLongitudeRandom)
        let annotation = MKPointAnnotation()
        annotation.coordinate = randomBlueFlagCoord
        annotation.title = "blue_flag"
        if flagInsidePolygon(annotation.coordinate) == true {
            blueFlagLocation = ["lat": "\(annotation.coordinate.latitude)", "long": "\(annotation.coordinate.longitude)"]

                mapView.addAnnotation(annotation)
            
        } else {
            addFlag1()
        }
    }
    
    func addFlag2() {
        let greenFlagCoord = boundaryArray[3]
        let greenFlagLatitudeRandom = greenFlagCoord.latitude + (Double(arc4random_uniform(20)) / 10000) - (Double(arc4random_uniform(20)) / 10000)
        let greenFlagLongitudeRandom =  greenFlagCoord.longitude + (Double(arc4random_uniform(20)) / 10000) - (Double(arc4random_uniform(20)) / 10000)
        let randomGreenFlagCoord = CLLocationCoordinate2D(latitude: greenFlagLatitudeRandom, longitude: greenFlagLongitudeRandom)
        let annotation = MKPointAnnotation()
        annotation.coordinate = randomGreenFlagCoord
        annotation.title = "green_flag"
        
        if flagInsidePolygon(annotation.coordinate) == true {
            greenFlagLocation = ["lat": "\(annotation.coordinate.latitude)", "long": "\(annotation.coordinate.longitude)"]

                mapView.addAnnotation(annotation)

        } else {
            addFlag2()
        }
        
    }
    
    // // // // // // // // // // //
    
    //POLYGON CHECK -- ARE YOU IN THE POLYGON???
    func userInsidePolygon(userlocation: CLLocationCoordinate2D ) -> Bool{
        // get every overlay on the map
        if mapView.overlays.count > 0 {
            let o = self.mapView.overlays[mapView.overlays.count - 1]
            // handle only polygon
            if o is MKPolygon{
                let polygon:MKPolygon =  o as! MKPolygon
//                print(polygon)
                let polygonPath:CGMutablePathRef  = CGPathCreateMutable()
                // get points of polygon
                
                let arrPoints = polygon.points()
//                print(polygon.points())
                // create cgpath
                for i in 0..<polygon.pointCount {
                    let polygonMapPoint: MKMapPoint = arrPoints[i]
                    let polygonCoordinate = MKCoordinateForMapPoint(polygonMapPoint)
                    let polygonPoint = self.mapView.convertCoordinate(polygonCoordinate, toPointToView: self.mapView)
    //                    print("polyMP", polygonMapPoint, "\npC", polygonCoordinate, "\npP", polygonPoint)
                    
                    if (i == 0){
                        CGPathMoveToPoint(polygonPath, nil, polygonPoint.x, polygonPoint.y)
                    }
                    else{
                        CGPathAddLineToPoint(polygonPath, nil, polygonPoint.x, polygonPoint.y)
                    }
                }
                let mapPointAsCGP:CGPoint = self.mapView.convertCoordinate(userlocation, toPointToView: self.mapView)
                return CGPathContainsPoint(polygonPath , nil, mapPointAsCGP, false)
            }
        }
        return false
    }

    //POLYGON CHECK -- ARE YOU IN GREEN ZONE???
    func userInsideGreenPolygon(userlocation: CLLocationCoordinate2D ) -> Bool{
        // get every overlay on the map
        if mapView.overlays.count > 0 {
            let o = self.mapView.overlays[1]
            // handle only polygon
            if o is MKPolygon{
                let polygon:MKPolygon =  o as! MKPolygon
//                print(polygon)
                let polygonPath:CGMutablePathRef  = CGPathCreateMutable()
                // get points of polygon
            
                let arrPoints = polygon.points()
//                print(polygon.points())
                // create cgpath
                for i in 0..<polygon.pointCount {
                    let polygonMapPoint: MKMapPoint = arrPoints[i]
                    let polygonCoordinate = MKCoordinateForMapPoint(polygonMapPoint)
                    let polygonPoint = self.mapView.convertCoordinate(polygonCoordinate, toPointToView: self.mapView)
//                    print("polyMP", polygonMapPoint, "\npC", polygonCoordinate, "\npP", polygonPoint)
                    
                    if (i == 0){
                        CGPathMoveToPoint(polygonPath, nil, polygonPoint.x, polygonPoint.y)
                    }
                    else{
                        CGPathAddLineToPoint(polygonPath, nil, polygonPoint.x, polygonPoint.y)
                    }
                }
                let mapPointAsCGP:CGPoint = self.mapView.convertCoordinate(userlocation, toPointToView: self.mapView)
                self.inBlueArea = true
                return CGPathContainsPoint(polygonPath , nil, mapPointAsCGP, false)
            }
        }
        self.inBlueArea = false
//        print("not blue")
        return false
    }
    
    //POLYGON CHECK -- IS THE FLAG IN THE POLYGON???
    func flagInsidePolygon(flaglocation: CLLocationCoordinate2D ) -> Bool{
        // get every overlay on the map
        if mapView.overlays.count > 0 {
            let o = self.mapView.overlays[mapView.overlays.count - 1]
            // handle only polygon
            if o is MKPolygon{
                let polygon:MKPolygon =  o as! MKPolygon
                //                print(polygon)
                let polygonPath:CGMutablePathRef  = CGPathCreateMutable()
                // get points of polygon
                
                let arrPoints = polygon.points()
//                print(polygon.points())
                // create cgpath
                for i in 0..<polygon.pointCount {
                    let polygonMapPoint: MKMapPoint = arrPoints[i]
                    let polygonCoordinate = MKCoordinateForMapPoint(polygonMapPoint)
                    let polygonPoint = self.mapView.convertCoordinate(polygonCoordinate, toPointToView: self.mapView)
                    //                    print("polyMP", polygonMapPoint, "\npC", polygonCoordinate, "\npP", polygonPoint)
                    
                    if (i == 0){
                        CGPathMoveToPoint(polygonPath, nil, polygonPoint.x, polygonPoint.y)
                    }
                    else{
                        CGPathAddLineToPoint(polygonPath, nil, polygonPoint.x, polygonPoint.y)
                    }
                }
                let mapPointAsCGP:CGPoint = self.mapView.convertCoordinate(flaglocation, toPointToView: self.mapView)
                return CGPathContainsPoint(polygonPath , nil, mapPointAsCGP, false)
            }
        }
        return false
    }
    
    //CLCircularRegion Check: Are you adjacent to a person?
    
    func amINearSomeoneElse() {
        
        for (_, person) in playersToDisplay {
            print("PERSON DATATATATATTAT", person["location"])
            let personLat = (person["location"]?!["lat"] as! NSString).doubleValue
            let personLong = (person["location"]?!["long"] as! NSString).doubleValue
            let radiusCoord = CLLocationCoordinate2DMake(personLat, personLong)
            if game_is_active == true {
                if userInsidePolygon(self.region!.center) == true {
                    if Int(person["number"]!! as! NSNumber) % 2 == 0 {
        //                print("they are on green team")
        //                print(radiusCoord)
                        if onBlueTeam == true {
                            if inBlueArea == false {
                                AudioServicesPlayAlertSound(alarmSound)
                                print("you got me")
                            } else {
                                AudioServicesPlayAlertSound(fanfare)
                                print("i got you, punk")
                            }
                        }
                    }
                } else {
    //                print("they are on blue team")
    //                print(radiusCoord)
                    let otherPlayerRegion = CLCircularRegion.init(center: radiusCoord, radius: 10, identifier: "otherPlayer")
                    if otherPlayerRegion.containsCoordinate(self.region!.center) {
                        if onBlueTeam == false {
                            if inBlueArea == true {
                                print("i'm out")
                                AudioServicesPlayAlertSound(alarmSound)
                            } else {
                                print("i caught you")
                                AudioServicesPlayAlertSound(fanfare)
                            }
                        }
                    }
                }
            }
        }
        
    }
    
}

