import UIKit
import AVFoundation
import ARKit
import CoreImage

class ViewController: UIViewController, ARSCNViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    let captureSession = AVCaptureSession()
    var videoOutput = AVCaptureMovieFileOutput()
    var videoDataOutput = AVCaptureVideoDataOutput()
    var isRecording = false
    let ciContext = CIContext()
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupARSession()
        setupVideoRecording()
        setupPreviewLayer()
    }
    
    func setupARSession() {
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)
        
        sceneView.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    func setupVideoRecording() {
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ カメラデバイスが見つかりません")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("❌ カメラ入力の作成に失敗: \(error.localizedDescription)")
            return
        }

        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        if let previewLayer = previewLayer {
            view.layer.insertSublayer(previewLayer, at: 0)
        }
    }
    
    @IBAction func toggleRecording(_ sender: UIButton) {
        if isRecording {
            videoOutput.stopRecording()
            sender.setTitle("Start Recording", for: .normal)
        } else {
            let outputFilePath = NSTemporaryDirectory() + "recordedVideo.mp4"
            let outputFileURL = URL(fileURLWithPath: outputFilePath)
            videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
            sender.setTitle("Stop Recording", for: .normal)
        }
        isRecording.toggle()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
        } else {
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, self, #selector(videoSaved(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    @objc func videoSaved(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error saving video: \(error.localizedDescription)")
        } else {
            print("Video saved successfully!")
        }
    }
    
    // カメラ映像にノイズを適用
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        let noiseImage = applyNoiseEffect(to: cameraImage)
        
        DispatchQueue.main.async {
            self.previewLayer?.contents = self.ciContext.createCGImage(noiseImage, from: noiseImage.extent)
        }
    }
    
    func applyNoiseEffect(to image: CIImage) -> CIImage {
        let noiseFilter = CIFilter(name: "CIRandomGenerator")!
        let noiseImage = noiseFilter.outputImage!
        let cropRect = CGRect(x: 0, y: 0, width: image.extent.width, height: image.extent.height)
        let croppedNoise = noiseImage.cropped(to: cropRect)
        
        let blendFilter = CIFilter(name: "CISourceOverCompositing")!
        blendFilter.setValue(croppedNoise, forKey: kCIInputImageKey)
        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return blendFilter.outputImage ?? image
    }
}
