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
    
    // A structure that contains RGB color intensity values.
    private var colors: AngleColors?
    
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
    
    // MARK: - Perform Requests
    
    private func processVideoFrame(_ framePixelBuffer: CVPixelBuffer) {
        // Perform the requests on the pixel buffer that contains the video frame.
        try? requestHandler.perform([segmentationRequest],
                                    on: framePixelBuffer,
                                    orientation: .right)
        
        // Get the pixel buffer that contains the mask image.
        guard let maskPixelBuffer =
                segmentationRequest.results?.first?.pixelBuffer else { return }
        
        // Process the images.
        blend(original: framePixelBuffer, mask: maskPixelBuffer)
    }
    
    // MARK: - Process Results
    
    // Performs the blend operation.
    private func blend(original framePixelBuffer: CVPixelBuffer,
                       mask maskPixelBuffer: CVPixelBuffer) {
        
        // Remove the optionality from generated color intensities or exit early.
      //  guard let colors = colors else { return }
        
        // Create CIImage objects for the video frame and the segmentation mask.
        let originalImage = CIImage(cvPixelBuffer: framePixelBuffer).oriented(.right)
        var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // Scale the mask image to fit the bounds of the video frame.
        //let scaleX = originalImage.extent.width / maskImage.extent.width
        //let scaleY = originalImage.extent.height / maskImage.extent.height
        //maskImage = maskImage.transformed(by: .init(scaleX: scaleX, y: scaleY))
        
        // Define RGB vectors for CIColorMatrix filter.
//        let vectors = [
//            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: colors.red),
//            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: colors.green),
//            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: colors.blue)
//        ]
//
        // Create a colored background image.
//        let backgroundImage = maskImage.applyingFilter("CIColorMatrix",
//                                                       parameters: vectors)
//
//        // Blend the original, background, and mask images.
//        let blendFilter = CIFilter.blendWithRedMask()
//        blendFilter.inputImage = originalImage
//        blendFilter.backgroundImage = backgroundImage
//        blendFilter.maskImage = maskImage
        
        // Set the new, blended image as current.
//        currentCIImage = blendFilter.outputImage?.oriented(.left)
        let inv = CIFilter(name: "CIColorInvert", parameters: [kCIInputImageKey: maskImage])!
        let blur = CIFilter(name:"CIBoxBlur", parameters: [kCIInputImageKey: inv.outputImage!, kCIInputRadiusKey: 20])!
        let halftone = CIFilter(name:"CIDotScreen", parameters: [kCIInputImageKey: blur.outputImage!, kCIInputWidthKey: 20])!
        let blur2 = CIFilter(name:"CIBoxBlur", parameters: [kCIInputImageKey: halftone.outputImage!, kCIInputRadiusKey: 60])!
        let halftone2 = CIFilter(name:"CIDotScreen", parameters: [kCIInputImageKey: blur2.outputImage!, kCIInputWidthKey: 60])!
        let falseColor = CIFilter(name:"CIFalseColor", parameters: [kCIInputImageKey: halftone2.outputImage!, "inputColor0": CIColor(color: UIColor.init(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.9)),"inputColor1": CIColor(color: UIColor.init(red: 0.8, green: 0.8, blue: 0.9, alpha: 0.9)),])!
        
        
      //  let filter2 = CIFilter(name: "CIDiscBlur")!                         // 2
      //  filter2.setValue(40, forKey: kCIInputRadiusKey)
                               // 3
      //  filter2.setValue(inv.outputImage, forKey: kCIInputImageKey)
        
//       let filter = CIFilter(name: "CIDotScreen")!                         // 2
//       filter.setValue(40, forKey: kCIInputWidthKey)
                              // 3
       // filter.setValue(halftone.outputImage, forKey: kCIInputImageKey)
       
        currentCIImage = falseColor.outputImage
    }
//
//    func resize (sourceImage:CIImage) -> CIImage{
//
//
//       // let context = CIContext()
//
//        let resizeFilter = CIFilter(name:"CILanczosScaleTransform")!
//
//        // Desired output size
//
//
//        // Compute scale and corrective aspect ratio
//        let scale = 8 / (sourceImage.extent.height)
//        let aspectRatio = 8 / ((sourceImage.extent.width) * scale)
//
//        // Apply resizing
//        resizeFilter.setValue(sourceImage, forKey: kCIInputImageKey)
//        resizeFilter.setValue(scale, forKey: kCIInputScaleKey)
//        resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
//       // print(resizeFilter.outputImage?.extent.width)
//        return resizeFilter.outputImage!
//    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Grab the pixelbuffer frame from the camera output
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        processVideoFrame(pixelBuffer)
    }
}
