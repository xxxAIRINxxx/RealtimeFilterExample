//
//  ViewController.swift
//  RealtimeFilterExample
//
//  Created by xxxAIRINxxx on 2015/03/17.
//  Copyright (c) 2015 xxxAIRINxxx. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var imageView : UIImageView!
    
    var session : AVCaptureSession = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.imageView!.backgroundColor = UIColor(patternImage: UIImage(named: "screentone")!)
        
        if self.setupCamera() {
            self.session.startRunning()
        } else {
            assertionFailure("setupCamera error!")
        }
    }

    func setupCamera() -> Bool {
        self.session.sessionPreset = AVCaptureSessionPresetMedium
        
        var targetDevice : AVCaptureDevice?
        
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        for device in devices {
            if device.position == .Back {
                targetDevice = device
                break
            }
        }
        
        if targetDevice == nil {
            return false
        }
        
        var inputError: NSError?
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: targetDevice!)
        } catch {
            return false
        }
        
        if self.session.canAddInput(input) {
            self.session.addInput(input)
        } else {
            return false
        }
        
        var lockError: NSError?
        do {
            try targetDevice!.lockForConfiguration()
            if let error = lockError {
                print("lock error: \(error.localizedDescription)")
                return false
            } else {
                if targetDevice!.smoothAutoFocusSupported {
                    targetDevice!.smoothAutoFocusEnabled = true
                }
                if targetDevice!.autoFocusRangeRestrictionSupported {
                    targetDevice!.focusMode = .ContinuousAutoFocus
                }
                targetDevice!.activeVideoMinFrameDuration = CMTimeMake(1, 15)
                targetDevice!.unlockForConfiguration()
            }
        } catch var error as NSError {
            lockError = error
        }
        
        let queue = dispatch_queue_create("realtime_filter_example_queue", DISPATCH_QUEUE_SERIAL)
        
        var output : AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true
        
        if self.session.canAddOutput(output) {
            self.session.addOutput(output)
        } else {
            return false
        }
        
        for connection in output.connections as! [AVCaptureConnection] {
            if connection.supportsVideoOrientation {
                connection.videoOrientation = AVCaptureVideoOrientation.Portrait
            }
        }
        
        return true
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        dispatch_sync(dispatch_get_main_queue(), { () -> Void in
            let image = self.imageFromSampleBuffer(sampleBuffer)
            
            if let bufferImage = image {
                let filteredImage = OpenCVSampleFilter.mangaImageFromUIImage(bufferImage)
                
                self.imageView!.image = filteredImage
            }
        })
    }

    // @see : http://giveitashot.hatenadiary.jp/entry/2014/10/19/190505
    
    func imageFromSampleBuffer(sampleBuffer: CMSampleBufferRef) -> UIImage? {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)
        let newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, bitmapInfo)
        
        let imageRef = CGBitmapContextCreateImage(newContext)
        let resultImage = UIImage(CGImage: imageRef)
        
        return resultImage
    }
}
