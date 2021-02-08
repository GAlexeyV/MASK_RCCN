import Foundation
import CoreGraphics
import CoreML
import CoreImage

@available(iOS 12.0, macOS 10.14, *)
public struct Detection {
    
    public let index:Int
    public let boundingBox:CGRect
    public let classId:Int
    public let score:Double
    public let mask:CGImage?
    
    public static func detectionsFromFeatureValue(featureValue:MLFeatureValue,
                                           maskFeatureValue:MLFeatureValue?) -> [Detection] {
        
        guard let rawDetections = featureValue.multiArrayValue else {
            return []
        }
        
        let detectionsCount = Int(truncating: rawDetections.shape[0])
        let detectionStride = Int(truncating: rawDetections.strides[0])
        
        var detections = [Detection]()
        
        for i in 0 ..< detectionsCount {
            
            let score = Double(truncating: rawDetections[i*detectionStride+5])
            if(score > 0.7) {
                
                let classId = Int(truncating: rawDetections[i*detectionStride+4])
                let y1 = CGFloat(truncating: rawDetections[i*detectionStride])
                let x1 = CGFloat(truncating: rawDetections[i*detectionStride+1])
                let y2 = CGFloat(truncating: rawDetections[i*detectionStride+2])
                let x2 = CGFloat(truncating: rawDetections[i*detectionStride+3])
                let width = x2-x1
                let height = y2-y1
                
                let mask:CGImage? = {
                    if let maskFeatureValue = maskFeatureValue {
                        return maskFromFeatureValue(maskFeatureValue: maskFeatureValue, atIndex: i)
                    }
                    return nil
                }()
                
                let detection = Detection(index:i, boundingBox: CGRect(x: x1, y: y1, width: width, height: height), classId: classId, score: score, mask:mask)
                detections.append(detection)
            }
            
        }
        
        return detections
    }
    
    static func maskFromFeatureValue(maskFeatureValue:MLFeatureValue, atIndex index:Int) -> CGImage? {
        
        guard let rawMasks = maskFeatureValue.multiArrayValue else {
            return nil
        }
        
        let maskCount = Int(truncating: rawMasks.shape[0])
        
        guard maskCount > index else {
            return nil
        }
        
        let maskStride = Int(truncating: rawMasks.strides[0])
        assert(rawMasks.dataType == .double)
        var maskData = Array<Double>(repeating: 0.0, count: maskStride)
        let maskDataPointer = UnsafeMutableRawPointer(&maskData)
        let elementSize = MemoryLayout<Double>.size
        maskDataPointer.copyMemory(from: rawMasks.dataPointer.advanced(by: maskStride*elementSize*index), byteCount: maskStride*elementSize)

        var intMaskData = maskData.map { (doubleValue) -> UInt8 in
            return UInt8(255-(doubleValue/2*255))
        }
        
        let intMaskDataPointer = UnsafeMutablePointer<UInt8>(&intMaskData)
        let data = CFDataCreate(nil, intMaskDataPointer, maskData.count)!
        
        let image = CGImage(maskWidth: 28,
                            height: 28,
                            bitsPerComponent: 8,
                            bitsPerPixel: 8,
                            bytesPerRow: 28,
                            provider: CGDataProvider(data: data)!,
                            decode: nil,
                            shouldInterpolate: false)
        return image
    }
    
}
