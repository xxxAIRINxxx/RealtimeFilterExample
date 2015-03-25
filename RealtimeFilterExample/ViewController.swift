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
            println("setupCamera error!")
        }
    }

    func setupCamera() -> Bool {
        self.session.sessionPreset = AVCaptureSessionPresetMedium
        
        var targetDevice : AVCaptureDevice?
        
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as [AVCaptureDevice]
        for device in devices {
            if device.position == .Back {
                targetDevice = device as AVCaptureDevice
                break
            }
        }
        
        if targetDevice == nil {
            return false
        }
        
        var inputError: NSError?
        let input: AVCaptureDeviceInput? = AVCaptureDeviceInput.deviceInputWithDevice(targetDevice, error: &inputError) as? AVCaptureDeviceInput
        if let aInput = input {
            if self.session.canAddInput(aInput) {
                self.session.addInput(aInput)
            } else {
                return false
            }
        } else {
            if let error = inputError {
                println("input error: \(error.localizedDescription)")
            }
            return false
        }
        
        var lockError: NSError?
        if targetDevice!.lockForConfiguration(&lockError) {
            if let error = lockError {
                println("lock error: \(error.localizedDescription)")
                return false
            } else {
                targetDevice!.activeVideoMinFrameDuration = CMTimeMake(1, 15)
                targetDevice!.unlockForConfiguration()
            }
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
        
        for connection in output.connections as [AVCaptureConnection] {
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
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, UInt(0))
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitsPerCompornent : UInt = 8
        var bitmapInfo = CGBitmapInfo(CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)
        let newContext = CGBitmapContextCreate(baseAddress, width, height, bitsPerCompornent, bytesPerRow, colorSpace, bitmapInfo)
        
        let imageRef = CGBitmapContextCreateImage(newContext)
        let resultImage = UIImage(CGImage: imageRef)
        
        return resultImage
    }
}
