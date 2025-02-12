import Foundation
import CoreGraphics
import ImageIO
import OSLog
import UniformTypeIdentifiers

class ImageConversionService {
    
    private let ICSLog = OSLog(subsystem: subsystem, category: "ImageConversion")
    
    func convertJ2KToJPEG(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
        // Ensure we can access the input file
        guard FileManager.default.isReadableFile(atPath: inputURL.path) else {
            os_log("Error: Input file is not readable at path: %{public}s", log: ICSLog, type: .error, inputURL.path)
            completion(false)
            return
        }
        
        // Convert URLs to C strings for OpenJPEG
        let inputPath = inputURL.path.cString(using: .utf8)!
        
        // Initialize OpenJPEG decoder
        guard let decoder = opj_create_decompress(OPJ_CODEC_J2K) else {
            os_log("Error: Failed to create decoder", log: ICSLog, type: .error)
            completion(false)
            return
        }
        defer { opj_destroy_codec(decoder) }
        
        // Set default decoding parameters
        var parameters = opj_dparameters_t()
        opj_set_default_decoder_parameters(&parameters)
        
        // Setup decoder
        guard opj_setup_decoder(decoder, &parameters) == OPJ_TRUE else {
            os_log("Error: Failed to setup decoder", log: ICSLog, type: .error)
            completion(false)
            return
        }
        
        // Open input file stream
        guard let inputStream = opj_stream_create_default_file_stream(inputPath, 1) else {
            os_log("Error: Failed to create input stream at path: %{public}s", log: ICSLog, type: .error, inputURL.path)
            completion(false)
            return
        }
        defer { opj_stream_destroy(inputStream) }
        
        // Read header
        var image: UnsafeMutablePointer<opj_image_t>?
        guard opj_read_header(inputStream, decoder, &image) == OPJ_TRUE else {
            os_log("Error: Failed to read header", log: ICSLog, type: .error)
//            print("Error: Failed to read header")
            completion(false)
            return
        }
        
        // Decode image
        guard opj_decode(decoder, inputStream, image) == OPJ_TRUE,
              let imageRef = image else {
            os_log("Error: Failed to decode image", log: ICSLog, type: .error)
//            print("Error: Failed to decode image")
            completion(false)
            return
        }
        defer { opj_image_destroy(imageRef) }
        
        // Get image properties
        let width = Int(imageRef.pointee.x1 - imageRef.pointee.x0)
        let height = Int(imageRef.pointee.y1 - imageRef.pointee.y0)
        let numComps = Int(imageRef.pointee.numcomps)
        
        // Create CGContext for the image
        let bytesPerRow = width * 4 // RGBA
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
//            print("Error: Failed to create CGContext")
            os_log("Error: Failed to create CGContext", log: ICSLog, type: .error)
            completion(false)
            return
        }
        
        // Get the data buffer
        guard let buffer = context.data else {
            os_log("Error: Failed to get context data buffer", log: ICSLog, type: .error)
//            print("Error: Failed to get context data buffer")
            completion(false)
            return
        }
        
        // Convert image data
        let ptr = buffer.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let pixel = y * width + x
                let offset = pixel * 4 // RGBA
                
                // Get component values
                var red: UInt8 = 0
                var green: UInt8 = 0
                var blue: UInt8 = 0
                
                if numComps >= 3 {
                    // RGB image
                    red = UInt8(min(max(imageRef.pointee.comps[0].data[pixel], 0), 255))
                    green = UInt8(min(max(imageRef.pointee.comps[1].data[pixel], 0), 255))
                    blue = UInt8(min(max(imageRef.pointee.comps[2].data[pixel], 0), 255))
                } else {
                    // Grayscale image
                    let gray = UInt8(min(max(imageRef.pointee.comps[0].data[pixel], 0), 255))
                    red = gray
                    green = gray
                    blue = gray
                }
                
                // Set RGBA values
                ptr[offset] = red
                ptr[offset + 1] = green
                ptr[offset + 2] = blue
                ptr[offset + 3] = 255 // Alpha
            }
        }
        
        // Create CGImage
        guard let cgImage = context.makeImage() else {
            os_log("Error: Failed to create CGImage", log: ICSLog, type: .error)
//            print("Error: Failed to create CGImage")
            completion(false)
            return
        }
        
        // Convert to JPEG data
        let jpegType = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, jpegType, 1, nil) else {
//            print("Error: Failed to create image destination")
            os_log("Error: Failed to create image destination", log: ICSLog, type: .error)
            completion(false)
            return
        }
        
        // Set compression quality
        let properties = [kCGImageDestinationLossyCompressionQuality as String: 0.8] as [String: Any] as CFDictionary
        
        // Add the image to the destination
        CGImageDestinationAddImage(destination, cgImage, properties)
        
        // Finalize the JPEG file
        guard CGImageDestinationFinalize(destination) else {
            os_log("Error: Failed to write JPEG file", log: ICSLog, type: .error)
            completion(false)
            return
        }
        
        completion(true)
        return
    }
}
