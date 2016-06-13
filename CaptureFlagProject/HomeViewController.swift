//
//  HomeViewController.swift
//  CaptureFlagProject
//
//  Created by Vu Dinh on 5/26/16.
//  Copyright © 2016 Vu Dinh. All rights reserved.
//

import UIKit
import Firebase
import FirebaseDatabase
import FBSDKCoreKit
import FBSDKLoginKit

class HomeViewController : UIViewController {
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var displayNameLabel: UILabel!
    
    
    
    let ref = FIRDatabase.database().reference()

    override func viewDidLoad() {
        super.viewDidLoad()
        if let user = FIRAuth.auth()?.currentUser {
            print("user ==",user.uid)
            ref.child("users/\(user.uid)").observeSingleEventOfType(.Value, withBlock: { (snapshot) in
                
                print(snapshot, "GGETTING USERSE BACK")
                
                guard let value = snapshot.value as? Dictionary<String, AnyObject>
                    else {
                        print("Theres no value");
                        return
                    }
                print(value)
                let graphRequest = FBSDKGraphRequest(graphPath: "me", parameters: ["fields": "cover"])
                graphRequest.startWithCompletionHandler({ (connection, result, error) in
                    if error != nil {
                        print(error.localizedDescription)
                        return
                    }
                    let accessToken = result.valueForKey("id") as! String
                    let profileImageURL = NSURL(string: "https://graph.facebook.com/\(accessToken)/picture?type=large")
                    print("Profile Image UrL", profileImageURL)
                    let pictureData = NSData(contentsOfURL: profileImageURL!)
                    self.profileImageView.image = UIImage(data: pictureData!)
                    self.displayNameLabel.text = user.displayName

                    //Make profile image a circle
                    self.profileImageView.layer.borderWidth = 1
                    self.profileImageView.layer.masksToBounds = false
                    self.profileImageView.layer.borderColor = UIColor.blackColor().CGColor
                    self.profileImageView.layer.cornerRadius = self.profileImageView.frame.height/2
                    self.profileImageView.clipsToBounds = true
                })
            })
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let navigationController = segue.destinationViewController as! UINavigationController
        let controller = navigationController.topViewController as! ViewController
        if segue.identifier == "join_game_segue" {

        }
        if segue.identifier == "create_game_segue" {
            controller.isGameCreator = true
        }
    }
    
    
}






