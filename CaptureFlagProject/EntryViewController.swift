//
//  EntryViewController.swift
//  
//
//  Created by Michael Arbogast on 5/24/16.
//
//

import UIKit
import MapKit
import CoreLocation
import Firebase
import FirebaseAuth
import FBSDKCoreKit
import FBSDKLoginKit
import FirebaseDatabase

class EntryViewController: UIViewController, FBSDKLoginButtonDelegate, CLLocationManagerDelegate {
    let ref = FIRDatabase.database().reference()
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization() //only use when app in use
        
        
        let fbLoginButton = FBSDKLoginButton()
        fbLoginButton.center = view.center
        fbLoginButton.delegate = self
        view.addSubview(fbLoginButton)
    }

    func loginButton(loginButton: FBSDKLoginButton!, didCompleteWithResult result: FBSDKLoginManagerLoginResult!, error: NSError!) {
        if error != nil {
            print(error.localizedDescription)
            return
        }
        
        let credential = FIRFacebookAuthProvider.credentialWithAccessToken(FBSDKAccessToken.currentAccessToken().tokenString)
        
        FIRAuth.auth()?.signInWithCredential(credential, completion: {(user, error) in
            if error != nil {
                print(error?.localizedDescription)
                return
            }
            guard let user = user else {return}
            print(user.displayName)
            //save user first and last name
            
            var userDictionary = Dictionary<String, AnyObject>()
            
            print(user.photoURL)
            
            let names = user.displayName?.componentsSeparatedByString(" ")
            userDictionary["first_name"] = names![0]
            userDictionary["last_name"] = names![1]
            userDictionary["is_active"] = "true"
            userDictionary["is_ready"] = "false"
            userDictionary["number"] = 0
            userDictionary["location"] = ["lat": "false", "long": "false"]
            
            
            
            self.ref.child("users/\(user.uid)").setValue(userDictionary)
            self.performSegueWithIdentifier("user_logged_in_home", sender: nil)
        })
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if FIRAuth.auth()?.currentUser != nil {
            performSegueWithIdentifier("user_logged_in_home", sender: nil) //THIS LOGS YOU IN AUTOMATICALLY

        }
    }
    
    

    //DELEGATE METHODS
    func loginButtonWillLogin(loginButton: FBSDKLoginButton!) -> Bool {
        return true
    }

    func loginButtonDidLogOut(loginButton: FBSDKLoginButton!) {
        
    }
}
