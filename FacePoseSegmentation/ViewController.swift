/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app shows how to use Vision person segmentation and detect face
 to perform realtime image masking effects.
*/
import Foundation
import UIKit
import Vision
import MetalKit
import AVFoundation
import CoreImage.CIFilterBuiltins

final class ViewController: UIViewController {
    
    // The Vision requests and the handler to perform them.
    private let requestHandler = VNSequenceRequestHandler()
    private var facePoseRequest: VNDetectFaceRectanglesRequest!
    private var segmentationRequest = VNGeneratePersonSegmentationRequest()

    @IBOutlet weak var cameraView: MTKView! {
        didSet {
            guard metalDevice == nil else { return }
            setupMetal()
            setupCoreImage()
            setupCaptureSession()
        }
    }
    
    // The Metal pipeline.
    public var metalDevice: MTLDevice!
    public var metalCommandQueue: MTLCommandQueue!
    
    // The Core Image pipeline.
    public var ciContext: CIContext!
    public var currentCIImage: CIImage? {
        didSet {
            cameraView.draw()
        }
    }
    
    // The capture session that provides video frames.
    public var session: AVCaptureSession?
    
    // MARK: - ViewController LifeCycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        intializeRequests()
    }
    
    deinit {
        session?.stopRunning()
    }
    
    // MARK: - Prepare Requests
    
    private func intializeRequests() {
        
       
        // Create a request to segment a person from an image.
        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .balanced
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }
    

    // MARK: - Process Results
    
    // Performs the blend operation.
    private func applyFilters(mask maskPixelBuffer: CVPixelBuffer) {

       // let originalImage = CIImage(cvPixelBuffer: framePixelBuffer).oriented(.right)
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        let inv = CIFilter(name: "CIColorInvert", parameters: [kCIInputImageKey: maskImage])!
        let blur = CIFilter(name:"CIBoxBlur", parameters: [kCIInputImageKey: inv.outputImage!, kCIInputRadiusKey: 20])!
        let halftone = CIFilter(name:"CIDotScreen", parameters: [kCIInputImageKey: blur.outputImage!, kCIInputWidthKey: 20])!
        let blur2 = CIFilter(name:"CIBoxBlur", parameters: [kCIInputImageKey: halftone.outputImage!, kCIInputRadiusKey: 60])!
        let halftone2 = CIFilter(name:"CIDotScreen", parameters: [kCIInputImageKey: blur2.outputImage!, kCIInputWidthKey: 60])!
        let falseColor = CIFilter(name:"CIFalseColor", parameters: [kCIInputImageKey: halftone2.outputImage!, "inputColor0": CIColor(color: UIColor.init(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.9)),"inputColor1": CIColor(color: UIColor.init(red: 0.8, green: 0.8, blue: 0.9, alpha: 0.9)),])!

        currentCIImage = falseColor.outputImage?.cropped(to: maskImage.extent)
    }

    func resize (sourceImage:CIImage) -> CIImage{
        let resizeFilter = CIFilter(name:"CILanczosScaleTransform")!

        // Desired output size


        // Compute scale and corrective aspect ratio
        let scale = 100 / (sourceImage.extent.height)
        let aspectRatio = 100 / ((sourceImage.extent.width) * scale)

        // Apply resizing
        resizeFilter.setValue(sourceImage, forKey: kCIInputImageKey)
        resizeFilter.setValue(scale, forKey: kCIInputScaleKey)
        resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
       // print(resizeFilter.outputImage?.extent.width)
        return resizeFilter.outputImage!
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Grab the pixelbuffer frame from the camera output
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        try? requestHandler.perform([segmentationRequest],
                                    on: pixelBuffer,
                                    orientation: .right)
        
        // Get the pixel buffer that contains the mask image.
        guard let maskPixelBuffer =
                segmentationRequest.results?.first?.pixelBuffer else { return }
        applyFilters(mask: maskPixelBuffer)
    }
}
