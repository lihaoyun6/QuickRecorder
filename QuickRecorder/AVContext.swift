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
    func recordingCamera(withDevice: AVCaptureDevice) {
        SCContext.previewSession = AVCaptureSession()
        
        guard let input = try? AVCaptureDeviceInput(device: withDevice),
              SCContext.previewSession.canAddInput(input) else {
            print("Failed to set up camera")
            return
        }
        SCContext.previewSession.addInput(input)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: .global())
        
        if SCContext.previewSession.canAddOutput(videoOutput) {
            SCContext.previewSession.addOutput(videoOutput)
        }
        
        SCContext.previewSession.startRunning()
        DispatchQueue.main.async { self.startCameraOverlayer() }
    }
    
    func closeCamera() {
        if SCContext.isCameraRunning() {
            if camWindow.isVisible { camWindow.close() }
            SCContext.previewSession.stopRunning()
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

class AVOutputClass: NSObject, AVCaptureFileOutputRecordingDelegate {
    static let shared = AVOutputClass()
    var output: AVCaptureMovieFileOutput!
    //var captureSession: AVCaptureSession!
    
    public func startRecording(withDevice: AVCaptureDevice, mute: Bool = false, preset: AVCaptureSession.Preset = .high) {
        output = AVCaptureMovieFileOutput()
        SCContext.captureSession = AVCaptureSession()
        SCContext.previewSession = AVCaptureSession()
        SCContext.captureSession.sessionPreset = preset
        SCContext.previewSession.sessionPreset = preset
        
        guard let input = try? AVCaptureDeviceInput(device: withDevice),
              let preview = try? AVCaptureDeviceInput(device: withDevice),
              SCContext.captureSession.canAddInput(input),
              SCContext.previewSession.canAddInput(preview),
              SCContext.captureSession.canAddOutput(output),
            SCContext.previewSession.canAddOutput(output) else {
            print("Failed to set up camera or device")
            return
        }
        
        SCContext.captureSession.addInput(input)
        SCContext.captureSession.addOutput(output)
        SCContext.previewSession.addInput(preview)
        
        if mute {
            if let audioConnection = output.connection(with: .audio) {
                SCContext.captureSession.removeConnection(audioConnection)
                /*DispatchQueue.main.async {
                    let alert = AppDelegate.shared.createAlert(title: "No Audio Connection",
                                                               message: "Unable to get audio stream on this device, only screen content will be recorded!",
                                                               button1: "OK")
                    alert.runModal()
                }*/
            }
        }
        
        let encoderIsH265 = ud.string(forKey: "encoder") == Encoder.h265.rawValue
        let videoSettings: [String: Any] = [ AVVideoCodecKey: encoderIsH265 ? AVVideoCodecType.hevc : AVVideoCodecType.h264 ]
        guard let connection = output.connection(with: .video) else { return }
        output.setOutputSettings(videoSettings, for: connection)
        let fileEnding = ud.string(forKey: "videoFormat") ?? ""
        SCContext.filePath = "\(SCContext.getFilePath()).\(fileEnding)"
        SCContext.captureSession.startRunning()
        SCContext.previewSession.startRunning()
        output.startRecording(to: URL(fileURLWithPath: SCContext.filePath), recordingDelegate: self)
        SCContext.startTime = Date.now
        SCContext.streamType = StreamType.idevice
        DispatchQueue.main.async {
            for w in NSApplication.shared.windows.filter({ $0.title == "QuickReader".local }) { w.close() }
            AppDelegate.shared.updateStatusBar()
            AppDelegate.shared.startCameraOverlayer(size: NSSize(width: 300, height: 500))
        }
    }

    public func stopRecording() {
        if SCContext.captureSession.isRunning {
            DispatchQueue.main.async { [] in
                statusBarItem.isVisible = false
                if camWindow.isVisible { camWindow.close() }
            }
            output.stopRecording()
            SCContext.captureSession.stopRunning()
            SCContext.previewSession.stopRunning()
            SCContext.streamType = nil
            SCContext.startTime = nil
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        //print("Finish Recording.")
    }
}
