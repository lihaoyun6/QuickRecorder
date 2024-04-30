//
//  AVContext.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/27.
//
import AppKit
import Foundation
import AVFoundation

extension AppDelegate {
    func recordingCamera(withName: String) {
        SCContext.captureSession = AVCaptureSession()
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: .unspecified)
        guard let camera = discoverySession.devices.first(where: { $0.localizedName == withName }),
              let input = try? AVCaptureDeviceInput(device: camera),
              SCContext.captureSession.canAddInput(input) else {
            print("Failed to set up camera")
            return
        }
        SCContext.captureSession.addInput(input)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: .global())
        
        if SCContext.captureSession.canAddOutput(videoOutput) {
            SCContext.captureSession.addOutput(videoOutput)
        }
        
        SCContext.captureSession.startRunning()
        DispatchQueue.main.async { self.startCameraOverlayer() }
    }
    
    func closeCamera() {
        if SCContext.isCameraRunning() {
            if camWindow.isVisible { camWindow.close() }
            SCContext.captureSession!.stopRunning()
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !SCContext.isPaused && ud.string(forKey: "recordCam") != "Disabled".local {
            //保留后续以作他用
            //if sampleBuffer.isValid { SCContext.isCameraReady = true }
            //if sampleBuffer.imageBuffer != nil { SCContext.frameCache = sampleBuffer }
        }
    }
}
