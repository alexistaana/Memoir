//
//  ARViewController.swift
//  AR_Message
//
//  Created by Carlos Loeza on 12/1/21.
//

import UIKit
import RealityKit
import Combine
import ARKit

class ARViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet weak var ARView: ARView!
    
    // Hold messages users post
    var userMessages = [MessageEntity]()
    
    @IBOutlet weak var errorMessageLabel: ErrorMessageLabel!
    var subscription: Cancellable!
    // Dim background so user can focus on message while typing
    var shadeView: UIView!
    // Get the keyboard height once user starts typing
    var keyboardHeight: CGFloat!
    // Button will remove all messages on the screen
    var clearButton: UIButton!

    
    override func viewDidLoad() {
        super.viewDidLoad()

        ARGeoTrackingConfiguration.checkAvailability { (available, error) in
            guard available else {
                print("geo location does not works :( !")
                return }
            print("geo location does works :) !")
            self.ARView.session.run(ARGeoTrackingConfiguration())
        }
        // Update our screen constantly since user's phone constantly moves
        subscription = ARView.scene.subscribe(to: SceneEvents.Update.self) { [unowned self] in
            self.updateScene(on: $0)
        }
        // setup gestures to recognize user actions
        arViewUserGestures()
        // setup
        overlayUISetup()
        
        ARView.session.delegate = self
    }


    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Add observer to the keyboardWillShowNotification to get the height of the keyboard every time it is shown
        let notificationName = UIResponder.keyboardWillShowNotification
        let selector = #selector(keyboardIsPoppingUp(notification:))
        NotificationCenter.default.addObserver(self, selector: selector, name: notificationName, object: nil)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
    }
    
    
    
    func updateScene(on event: SceneEvents.Update) {
        // Make sure messages are not being updated by user, else do not accept messages
        let messagesToUpdate = userMessages.compactMap { !$0.isEditing && !$0.isDragging ? $0 : nil }
        // get one message at a time.
        // for loop will iterate through each note
        for message in messagesToUpdate {
            // Get a 3D point (user's message) and convert it to 2D
            guard let projectedPoint = ARView.project(message.position) else { return }
            // Get the camera point of view.
            let cameraForward = ARView.cameraTransform.matrix.columns.2.xyz
            // get location of note and arview camera location in order to normalize
            let cameraToWorldPointDirection = normalize(message.transform.translation - ARView.cameraTransform.translation)
            // get dot product
            let dotProduct = dot(cameraForward, cameraToWorldPointDirection)
            // if dotProduct is greater than 0, user can see message from their iphone's point of view
            let isVisible = dotProduct < 0

            // Since phone is constantly moving, we need to update the user's point of view constantly.
            // This will help us display the messages in the correct location
            message.projection = Projection(projectedPoint: projectedPoint, isVisible: isVisible)
            message.updateScreenPosition()
        }
    }
    
    // clear all of the messages in our AR world
    // Ex: if 5 messages exist, clear() will remove all from our AR world
    func clear() {
        // get configuration for our AR view
        guard let configuration = ARView.session.configuration else { return }
        // remove anchors from our arView
        ARView.session.run(configuration, options: .removeExistingAnchors)
        // for loop removes message from our list of messages
        for message in userMessages {
            deleteMessage(message)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.clear()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    

}

