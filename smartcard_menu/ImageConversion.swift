import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

class ImageConversionService {
    func convertJ2KToJPEG(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
        // Ensure we can access the input file
        guard FileManager.default.isReadableFile(atPath: inputURL.path) else {
            print("Error: Input file is not readable at path: \(inputURL.path)")
            completion(false)
            return
        }
        
        // Convert URLs to C strings for OpenJPEG
        let inputPath = inputURL.path.cString(using: .utf8)!
        
        // Initialize OpenJPEG decoder
        guard let decoder = opj_create_decompress(OPJ_CODEC_J2K) else {
            print("Error: Failed to create decoder")
            completion(false)
            return
        }
        defer { opj_destroy_codec(decoder) }
        
        // Set default decoding parameters
        var parameters = opj_dparameters_t()
        opj_set_default_decoder_parameters(&parameters)
        
        // Setup decoder
        guard opj_setup_decoder(decoder, &parameters) == OPJ_TRUE else {
            print("Error: Failed to setup decoder")
            completion(false)
            return
        }
        
        // Open input file stream
        guard let inputStream = opj_stream_create_default_file_stream(inputPath, 1) else {
            print("Error: Failed to create input stream at path: \(inputURL.path)")
            completion(false)
            return
        }
        defer { opj_stream_destroy(inputStream) }
        
        // Read header
        var image: UnsafeMutablePointer<opj_image_t>?
        guard opj_read_header(inputStream, decoder, &image) == OPJ_TRUE else {
            print("Error: Failed to read header")
            completion(false)
            return
        }
        
        // Decode image
        guard opj_decode(decoder, inputStream, image) == OPJ_TRUE,
              let imageRef = image else {
            print("Error: Failed to decode image")
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
            print("Error: Failed to create CGContext")
            completion(false)
            return
        }
        
        // Get the data buffer
        guard let buffer = context.data else {
            print("Error: Failed to get context data buffer")
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
            print("Error: Failed to create CGImage")
            completion(false)
            return
        }
        
        // Convert to JPEG data
        let jpegType = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, jpegType, 1, nil) else {
            print("Error: Failed to create image destination")
            completion(false)
            return
        }
        
        // Set compression quality
        let properties = [kCGImageDestinationLossyCompressionQuality as String: 0.8] as [String: Any] as CFDictionary
        
        // Add the image to the destination
        CGImageDestinationAddImage(destination, cgImage, properties)
        
        // Finalize the JPEG file
        guard CGImageDestinationFinalize(destination) else {
            print("Error: Failed to write JPEG file")
            completion(false)
            return
        }
        
        completion(true)
        return
    }
}
//        // Ensure the input file is readable
//        guard FileManager.default.isReadableFile(atPath: inputURL.path) else {
//            print("❌ Error: Input file is not readable at path: \(inputURL.path)")
//            completion(false)
//            return
//        }
//
//        // Convert URLs to C strings for OpenJPEG
//        let inputPath = inputURL.path.cString(using: .utf8)!
//        
//        // Initialize OpenJPEG decoder
//        guard let decoder = opj_create_decompress(OPJ_CODEC_J2K) else {
//            print("❌ Error: Failed to create OpenJPEG decoder")
//            completion(false)
//            return
//        }
//        defer { opj_destroy_codec(decoder) }
//
//        // Set default decoding parameters
//        var parameters = opj_dparameters_t()
//        opj_set_default_decoder_parameters(&parameters)
//
//        // Setup decoder
//        guard opj_setup_decoder(decoder, &parameters) == OPJ_TRUE else {
//            print("❌ Error: Failed to setup OpenJPEG decoder")
//            completion(false)
//            return
//        }
//
//        // Open input file stream
//        guard let inputStream = opj_stream_create_default_file_stream(inputPath, 1) else {
//            print("❌ Error: Failed to create input stream for \(inputURL.path)")
//            completion(false)
//            return
//        }
//        defer { opj_stream_destroy(inputStream) }
//
//        // Read header
//        var image: UnsafeMutablePointer<opj_image_t>?
//        guard opj_read_header(inputStream, decoder, &image) == OPJ_TRUE else {
//            print("❌ Error: Failed to read OpenJPEG header")
//            completion(false)
//            return
//        }
//
//        // Decode image
//        guard opj_decode(decoder, inputStream, image) == OPJ_TRUE,
//              let imageRef = image else {
//            print("❌ Error: Failed to decode OpenJPEG image")
//            completion(false)
//            return
//        }
//        defer { opj_image_destroy(imageRef) }
//
//        // Extract image properties
//        let width = Int(imageRef.pointee.x1 - imageRef.pointee.x0)
//        let height = Int(imageRef.pointee.y1 - imageRef.pointee.y0)
//        let numComps = Int(imageRef.pointee.numcomps)
//
//        // ✅ Ensure a CGContext is properly created here
//        let bytesPerRow = width * 4 // RGBA
//        guard let context = CGContext(data: nil,
//                                      width: width,
//                                      height: height,
//                                      bitsPerComponent: 8,
//                                      bytesPerRow: bytesPerRow,
//                                      space: CGColorSpaceCreateDeviceRGB(),
//                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
//            print("❌ Error: Failed to create CGContext")
//            completion(false)
//            return
//        }
//
//        // Get the data buffer
//        guard let buffer = context.data else {
//            print("❌ Error: Failed to get context data buffer")
//            completion(false)
//            return
//        }
//
//        // Convert image data into RGB buffer
//        let ptr = buffer.assumingMemoryBound(to: UInt8.self)
//        for y in 0..<height {
//            for x in 0..<width {
//                let pixel = y * width + x
//                let offset = pixel * 4 // RGBA
//                
//                // Get component values
//                var red: UInt8 = 0
//                var green: UInt8 = 0
//                var blue: UInt8 = 0
//                
//                if numComps >= 3 {
//                    // RGB image
//                    red = UInt8(min(max(imageRef.pointee.comps[0].data[pixel], 0), 255))
//                    green = UInt8(min(max(imageRef.pointee.comps[1].data[pixel], 0), 255))
//                    blue = UInt8(min(max(imageRef.pointee.comps[2].data[pixel], 0), 255))
//                } else {
//                    // Grayscale image
//                    let gray = UInt8(min(max(imageRef.pointee.comps[0].data[pixel], 0), 255))
//                    red = gray
//                    green = gray
//                    blue = gray
//                }
//
//                // Set RGBA values
//                ptr[offset] = red
//                ptr[offset + 1] = green
//                ptr[offset + 2] = blue
//                ptr[offset + 3] = 255 // Alpha
//            }
//        }
//
//        // ✅ Ensure the CGContext exists before calling makeImage()
//        guard let cgImage = context.makeImage() else {
//            print("❌ Error: Failed to create CGImage")
//            completion(false)
//            return
//        }
//
//        // ✅ Create the output directory if needed
//        let outputDir = outputURL.deletingLastPathComponent()
//        if !FileManager.default.fileExists(atPath: outputDir.path) {
//            do {
//                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
//            } catch {
//                print("❌ Error: Failed to create output directory: \(error.localizedDescription)")
//                completion(false)
//                return
//            }
//        }
//
//        // ✅ Convert CGImage to JPEG
//        let jpegType = UTType.jpeg.identifier as CFString
//        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, jpegType, 1, nil) else {
//            print("❌ Error: Failed to create image destination at \(outputURL.path)")
//            completion(false)
//            return
//        }
//
//        // Set compression quality
//        let properties = [kCGImageDestinationLossyCompressionQuality as String: 0.8] as [String: Any] as CFDictionary
//
//        // Add the image to the destination
//        CGImageDestinationAddImage(destination, cgImage, properties)
//
//        // Finalize and save the JPEG file
//        if CGImageDestinationFinalize(destination) {
//            print("✅ Successfully saved JPEG: \(outputURL.path)")
//            completion(true)
//        } else {
//            print("❌ Error: Failed to finalize JPEG file")
//            completion(false)
//        }
//    }
//}


//import Foundation
//import CoreGraphics
//import ImageIO
//import UniformTypeIdentifiers
//
//
//class ImageConversionService {
//    //    func sendAPDUCommand(apdu: [UInt8], completion: @escaping ([UInt8], UInt8, UInt8) -> Void) {
//    //    func convertJ2KToJPEG(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) -> Void{
//    //        // Ensure we can access the input file
//    //        guard FileManager.default.isReadableFile(atPath: inputURL.path) else {
//    //            print("Error: Input file is not readable at path: \(inputURL.path)")
//    ////            return false
//    //            completion(false)
//    //            return
//    //        }
//    //
//    //        // Convert URLs to C strings for OpenJPEG
//    //        let inputPath = inputURL.path.cString(using: .utf8)!
//    //
//    //        // Initialize OpenJPEG decoder
//    //        guard let decoder = opj_create_decompress(OPJ_CODEC_J2K) else {
//    //            print("Error: Failed to create decoder")
//    ////            return false
//    //            completion(false)
//    //            return
//    //        }
//    //        defer { opj_destroy_codec(decoder) }
//    //
//    //        // Set default decoding parameters
//    //        var parameters = opj_dparameters_t()
//    //        opj_set_default_decoder_parameters(&parameters)
//    //
//    //        // Setup decoder
//    //        guard opj_setup_decoder(decoder, &parameters) == OPJ_TRUE else {
//    //            print("Error: Failed to setup decoder")
//    ////            return false
//    //            completion(false)
//    //            return
//    //        }
//    //
//    //        // Open input file stream
//    //        guard let inputStream = opj_stream_create_default_file_stream(inputPath, 1) else {
//    //            print("Error: Failed to create input stream at path: \(inputURL.path)")
//    ////            return false
//    //            completion(false)
//    //            return
//    //        }
//    //        defer { opj_stream_destroy(inputStream) }
//    //
//    //        // Read header
//    //        var image: UnsafeMutablePointer<opj_image_t>?
//    //        guard opj_read_header(inputStream, decoder, &image) == OPJ_TRUE else {
//    //            print("Error: Failed to read header")
//    ////            return false
//    //            completion(false)
//    //            return
//    //        }
//    //
//    //        // Decode image
//    //        guard opj_decode(decoder, inputStream, image) == OPJ_TRUE,
//    //              let imageRef = image else {
//    //            print("Error: Failed to decode image")
//    ////            return false
//    //            completion(false)
//    //            return
//    //        }
//    //        defer { opj_image_destroy(imageRef) }
//    //
//    //        // Get image properties
//    //        let width = Int(imageRef.pointee.x1 - imageRef.pointee.x0)
//    //        let height = Int(imageRef.pointee.y1 - imageRef.pointee.y0)
//    //        let numComps = Int(imageRef.pointee.numcomps)
//    //
//    //        // Create CGContext for the image
//    //        let bytesPerRow = width * 4 // RGBA
//    //        guard let context = CGContext(data: nil,
//    //                                      width: width,
//    //                                      height: height,
//    //                                      bitsPerComponent: 8,
//    //                                      bytesPerRow: bytesPerRow,
//    //                                      space: CGColorSpaceCreateDeviceRGB(),
//    //                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
//    //            print("Error: Failed to create CGContext")
//    ////            return false
//    //            completion(false)
//    //            return
//    //        }
//    //
//    //        // Get the data buffer
//    //        guard let buffer = context.data else {
//    //            print("Error: Failed to get context data buffer")
//    ////            return false
//    //            completion(false)
//    //            return
//    //        }
//    //
//    //        // Convert image data
//    //        let ptr = buffer.assumingMemoryBound(to: UInt8.self)
//    //        for y in 0..<height {
//    //            for x in 0..<width {
//    //                let pixel = y * width + x
//    //                let offset = pixel * 4 // RGBA
//    //
//    //                // Get component values
//    //                var red: UInt8 = 0
//    //                var green: UInt8 = 0
//    //                var blue: UInt8 = 0
//    //
//    //                if numComps >= 3 {
//    //                    // RGB image
//    //                    red = UInt8(min(max(imageRef.pointee.comps[0].data[pixel], 0), 255))
//    //                    green = UInt8(min(max(imageRef.pointee.comps[1].data[pixel], 0), 255))
//    //                    blue = UInt8(min(max(imageRef.pointee.comps[2].data[pixel], 0), 255))
//    //                } else {
//    //                    // Grayscale image
//    //                    let gray = UInt8(min(max(imageRef.pointee.comps[0].data[pixel], 0), 255))
//    //                    red = gray
//    //                    green = gray
//    //                    blue = gray
//    //                }
//    //
//    //                // Set RGBA values
//    //                ptr[offset] = red
//    //                ptr[offset + 1] = green
//    //                ptr[offset + 2] = blue
//    //                ptr[offset + 3] = 255 // Alpha
//    //            }
//    //        }
//    //
//    //        // Create CGImage
//    //        guard let cgImage = context.makeImage() else {
//    //            print("Error: Failed to create CGImage")
//    //            completion(false)
//    ////            return false
//    //            return
//    //        }
//    //
//    //        // Convert to JPEG data
//    //        let jpegType = UTType.jpeg.identifier as CFString
//    //        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, jpegType, 1, nil) else {
//    //            print("Error: Failed to create image destination")
//    //            completion(false)
//    ////            return false
//    //            return
//    //        }
//    //
//    //        // Set compression quality
//    //        let properties = [kCGImageDestinationLossyCompressionQuality as String: 0.8] as [String: Any] as CFDictionary
//    //
//    //        // Add the image to the destination
//    //        CGImageDestinationAddImage(destination, cgImage, properties)
//    //
//    //        // Finalize the JPEG file
//    //        guard CGImageDestinationFinalize(destination) else {
//    //            print("Error: Failed to write JPEG file")
//    //            completion(false)
//    ////            return false
//    //            return
//    //        }
//    //
//    ////        return true
//    //    }
//    //}
//    //    // Main execution
//    ////    let args = CommandLine.arguments
//    ////    if args.count != 3 {
//    ////        print("Usage: program <input_codestream.j2k> <output.jpg>")
//    ////        exit(1)
//    ////    }
//    ////
//    ////    let inputURL = URL(fileURLWithPath: args[1])
//    ////    let outputURL = URL(fileURLWithPath: args[2])
//    ////
//    ////    // Add more detailed error checking for file paths
//    ////    if !FileManager.default.fileExists(atPath: inputURL.path) {
//    ////        print("Error: Input file does not exist at path: \(inputURL.path)")
//    ////        exit(1)
//    ////    }
//    ////
//    ////    // Check if output directory exists
//    ////    let outputDirectory = outputURL.deletingLastPathComponent()
//    ////    if !FileManager.default.fileExists(atPath: outputDirectory.path) {
//    ////        print("Error: Output directory does not exist at path: \(outputDirectory.path)")
//    ////        exit(1)
//    ////    }
//    ////
//    ////    if convertJ2KToJPEG(inputURL: inputURL, outputURL: outputURL) {
//    ////        print("Successfully converted J2K to JPEG")
//    ////    } else {
//    ////        print("Failed to convert J2K to JPEG")
//    ////        exit(1)
//    ////    }
//    //
//    ////}
//    func convertJ2KToJPEG(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
//        // Ensure the input file exists
//        guard FileManager.default.isReadableFile(atPath: inputURL.path) else {
//            print("Error: Input file is not readable at path: \(inputURL.path)")
//            completion(false)
//            return
//        }
//        
//        // 🔹 Ensure output directory exists
//        let outputDir = outputURL.deletingLastPathComponent()
//        if !FileManager.default.fileExists(atPath: outputDir.path) {
//            do {
//                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
//            } catch {
//                print("Error: Failed to create output directory: \(error.localizedDescription)")
//                completion(false)
//                return
//            }
//        }
//        
//        // 🔹 Check if output URL is valid (debugging)
//        print("Attempting to write JPEG to: \(outputURL.path)")
//        
//        // Convert to JPEG data
//        let jpegType = UTType.jpeg.identifier as CFString
//        
//        // 🔹 Ensure the output URL is a valid file path
//        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, jpegType, 1, nil) else {
//            print("❌ Error: Failed to create image destination at \(outputURL.path)")
//            completion(false)
//            return
//        }
//        
//        // Set compression quality
//        let properties = [kCGImageDestinationLossyCompressionQuality as String: 0.8] as [String: Any] as CFDictionary
//        
//        // 🔹 Ensure CGImage exists before adding it to the destination
//        guard let cgImage = context.makeImage() else {
//            print("❌ Error: Failed to create CGImage")
//            completion(false)
//            return
//        }
//        
//        // Add the image to the destination
//        CGImageDestinationAddImage(destination, cgImage, properties)
//        
//        // Finalize the JPEG file
//        if CGImageDestinationFinalize(destination) {
//            print("✅ Successfully saved JPEG: \(outputURL.path)")
//            completion(true)
//        } else {
//            print("❌ Error: Failed to finalize JPEG file")
//            completion(false)
//        }
//    }
//    
//}
