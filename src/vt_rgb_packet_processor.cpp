/*
 * This file is part of the OpenKinect Project. http://www.openkinect.org
 *
 * Copyright (c) 2014 individual OpenKinect contributors. See the CONTRIB file
 * for details.
 *
 * This code is licensed to you under the terms of the Apache License, version
 * 2.0, or, at your option, the terms of the GNU General Public License,
 * version 2.0. See the APACHE20 and GPL2 files for the text of the licenses,
 * or the following URLs:
 * http://www.apache.org/licenses/LICENSE-2.0
 * http://www.gnu.org/licenses/gpl-2.0.txt
 *
 * If you redistribute this file in source form, modified or unmodified, you
 * may:
 *   1) Leave this header intact and distribute it under the same terms,
 *      accompanying it with the APACHE20 and GPL20 files, or
 *   2) Delete the Apache 2.0 clause and accompany it with the GPL2 file, or
 *   3) Delete the GPL v2 clause and accompany it with the APACHE20 file
 * In all cases you must keep the copyright notice intact and include a copy
 * of the CONTRIB file.
 *
 * Binary distributions must follow the binary distribution requirements of
 * either License.
 */

#include <libfreenect2/rgb_packet_processor.h>
#include <libfreenect2/logging.h>

#include <VideoToolbox/VideoToolbox.h>
#include <CoreVideo/CVMetalTextureCache.h>
#include <Metal/Metal.h>

// Helper to access Metal device from C++
extern "C" {
    void* MTLCreateSystemDefaultDevice(void);
    void* objc_autoreleasePoolPush(void);
    void objc_autoreleasePoolPop(void*);
}

namespace libfreenect2 {

// Minimal RAII wrapper for NSAutoreleasePool using proper @autoreleasepool semantics
class ScopedAutoreleasePool {
    void* context;
public:
    ScopedAutoreleasePool() : context(objc_autoreleasePoolPush()) {}
    ~ScopedAutoreleasePool() { objc_autoreleasePoolPop(context); }
};

// RAII wrapper for CF objects to ensure proper cleanup
// Modernized to work seamlessly with @autoreleasepool
template<typename T>
class CFScope {
    T obj;
public:
    explicit CFScope(T o = nullptr) : obj(o) {}
    ~CFScope() { if (obj) CFRelease(obj); }
    
    T get() const { return obj; }
    T release() { T tmp = obj; obj = nullptr; return tmp; }
    void reset(T o = nullptr) { if (obj) CFRelease(obj); obj = o; }
    
    // Prevent copying
    CFScope(const CFScope&) = delete;
    CFScope& operator=(const CFScope&) = delete;
    
    // Allow moving
    CFScope(CFScope&& other) noexcept : obj(other.obj) { other.obj = nullptr; }
    CFScope& operator=(CFScope&& other) noexcept {
        if (this != &other) {
            if (obj) CFRelease(obj);
            obj = other.obj;
            other.obj = nullptr;
        }
        return *this;
    }
};

class VTFrame: public Frame
{
 public:
  VTFrame(size_t width, size_t height, size_t bytes_per_pixel, 
          CVPixelBufferRef pixelBuffer, CVMetalTextureCacheRef textureCache = nullptr) :
      Frame(width, height, bytes_per_pixel, nullptr),
      pixelBuffer(pixelBuffer),
      textureCache(textureCache) {
      
      // Try zero-copy Metal upload if available
      if (textureCache && pixelBuffer) {
          CVMetalTextureRef metalTextureRef = nullptr;
          CVReturn cvRet = CVMetalTextureCacheCreateTextureFromImage(
              kCFAllocatorDefault,
              textureCache,
              pixelBuffer,
              NULL,
              MTLPixelFormatBGRA8Unorm,
              width,
              height,
              0,
              &metalTextureRef);
          
          if (cvRet == kCVReturnSuccess && metalTextureRef) {
              // Get metal texture address for zero-copy access
              id<MTLTexture> metalTexture = (id<MTLTexture>)CVMetalTextureGetTexture(metalTextureRef);
              if (metalTexture) {
                  data = reinterpret_cast<unsigned char *>([metalTexture contents]);
                  usingMetal = true;
                  // Texture cache manages the reference - release after use
                  CFRelease(metalTextureRef);
                  return;
              }
              if (metalTextureRef) CFRelease(metalTextureRef);
          }
      }
      
      // Fallback to CPU access
      CVPixelBufferLockBaseAddress(pixelBuffer, 0);
      data = reinterpret_cast<unsigned char *>(CVPixelBufferGetBaseAddress(pixelBuffer));
      usingMetal = false;
  }

  ~VTFrame() {
      if (!usingMetal && pixelBuffer) {
          CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
      }
      if (pixelBuffer) {
          CVPixelBufferRelease(pixelBuffer);
      }
      if (textureCache) {
          CVMetalTextureCacheFlush(textureCache, 0);
      }
  }

 protected:
  CVPixelBufferRef pixelBuffer;
  CVMetalTextureCacheRef textureCache;
  bool usingMetal = false;
};

class VTRgbPacketProcessorImpl: public WithPerfLogging
{
 public:
  CMFormatDescriptionRef format = nullptr;
  VTDecompressionSessionRef decoder = nullptr;
  CVMetalTextureCacheRef textureCache = nullptr;
  CMVideoCodecType currentCodec = kCMVideoCodecType_JPEG;

  VTRgbPacketProcessorImpl() {
      @autoreleasepool {
          setupDecoder(kCMVideoCodecType_JPEG);
      }
  }

  ~VTRgbPacketProcessorImpl() {
      @autoreleasepool {
          if (decoder) {
              VTDecompressionSessionInvalidate(decoder);
              CFRelease(decoder);
          }
          if (format) {
              CFRelease(format);
          }
          if (textureCache) {
              CVMetalTextureCacheFlush(textureCache, 0);
              CFRelease(textureCache);
          }
      }
  }

  bool setupDecoder(CMVideoCodecType codecType) {
      @autoreleasepool {
          if (decoder && currentCodec == codecType) return true;
          
          // Cleanup existing decoder
          if (decoder) {
              VTDecompressionSessionInvalidate(decoder);
              CFRelease(decoder);
              decoder = nullptr;
          }
          if (format) {
              CFRelease(format);
              format = nullptr;
          }
          
          currentCodec = codecType;
          int32_t width = 1920, height = 1080;

          // Create format description with proper error checking
          OSStatus status = CMVideoFormatDescriptionCreate(
              kCFAllocatorDefault, 
              codecType, 
              width, 
              height, 
              NULL, 
              &format);
          
          if (status != noErr) {
              LOG_ERROR("CMVideoFormatDescriptionCreate failed: %d (codec: %d)", 
                        (int)status, (int)codecType);
              return false;
          }
          
          if (!format) {
              LOG_ERROR("CMVideoFormatDescriptionCreate returned NULL format");
              return false;
          }

          // Create output pixel buffer attributes with Metal compatibility
          int32_t pixelFormat = kCVPixelFormatType_32BGRA;
          CFScope<CFNumberRef> wNum(CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &width));
          CFScope<CFNumberRef> hNum(CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &height));
          CFScope<CFNumberRef> pNum(CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pixelFormat));
          
          if (!wNum.get() || !hNum.get() || !pNum.get()) {
              LOG_ERROR("Failed to create CFNumber objects");
              return false;
          }
          
          // Enable IOSurface for zero-copy sharing
          const void *iosurfaceKeys[] = { kCVPixelBufferIOSurfaceIsGlobalKey };
          const void *iosurfaceValues[] = { kCFBooleanTrue };
          CFScope<CFDictionaryRef> iosurfaceProps(CFDictionaryCreate(
              kCFAllocatorDefault,
              iosurfaceKeys,
              iosurfaceValues,
              1,
              &kCFTypeDictionaryKeyCallBacks,
              &kCFTypeDictionaryValueCallBacks));
          
          const void *outputKeys[] = {
              kCVPixelBufferPixelFormatTypeKey, 
              kCVPixelBufferWidthKey, 
              kCVPixelBufferHeightKey,
              kCVPixelBufferMetalCompatibilityKey,
              kCVPixelBufferIOSurfacePropertiesKey
          };
          
          const void *outputValues[] = {
              pNum.get(), 
              wNum.get(), 
              hNum.get(), 
              kCFBooleanTrue,
              iosurfaceProps.get()
          };

          CFScope<CFDictionaryRef> outputConfiguration(CFDictionaryCreate(
              kCFAllocatorDefault,
              outputKeys,
              outputValues,
              5,
              &kCFTypeDictionaryKeyCallBacks,
              &kCFTypeDictionaryValueCallBacks));
          
          if (!outputConfiguration.get()) {
              LOG_ERROR("Failed to create output configuration dictionary");
              return false;
          }

          // Create decoder specification with hardware acceleration hints
          CFScope<CFMutableDictionaryRef> decoderSpec(CFDictionaryCreateMutable(
              kCFAllocatorDefault,
              0,
              &kCFTypeDictionaryKeyCallBacks,
              &kCFTypeDictionaryValueCallBacks));
          
          if (!decoderSpec.get()) {
              LOG_ERROR("Failed to create decoder specification");
              return false;
          }
          
          // Enable hardware acceleration hints for modern macOS APIs
          CFDictionarySetValue(decoderSpec.get(), 
                             kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder,
                             kCFBooleanTrue);
          
          // Request hardware-only decoder for better performance (may fall back on older hardware)
          CFDictionarySetValue(decoderSpec.get(),
                             kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder,
                             kCFBooleanTrue);

          VTDecompressionOutputCallbackRecord callback = {
              &VTRgbPacketProcessorImpl::decodeFrame, 
              NULL
          };

          // Create decompression session with proper error handling
          status = VTDecompressionSessionCreate(
              kCFAllocatorDefault, 
              format, 
              decoderSpec.get(), 
              outputConfiguration.get(), 
              &callback, 
              &decoder);
          
          if (status != noErr) {
              LOG_ERROR("VTDecompressionSessionCreate failed: %d (codec: %d)", 
                        (int)status, (int)codecType);
              
              // Provide more specific error information
              switch (status) {
                  case kVTVideoDecoderNotAvailableNowErr:
                      LOG_ERROR("Video decoder not available - hardware may be busy");
                      break;
                  case kVTVideoDecoderUnsupportedDataFormatErr:
                      LOG_ERROR("Unsupported data format for this decoder");
                      break;
                  case kVTVideoDecoderMalfunctionErr:
                      LOG_ERROR("Decoder malfunction - try resetting");
                      break;
                  default:
                      break;
              }
              
              decoder = nullptr;
              return false;
          }
          
          if (!decoder) {
              LOG_ERROR("VTDecompressionSessionCreate returned NULL decoder");
              return false;
          }
          
          // Query and log supported pixel formats for debugging using VTSessionCopyProperty
          CFArrayRef supportedPixelFormats = nullptr;
          OSStatus queryStatus = VTSessionCopyProperty(
              decoder, 
              kVTDecompressionPropertyKey_SupportedPixelFormatsOut,
              kCFAllocatorDefault,
              &supportedPixelFormats);
          
          if (queryStatus == noErr && supportedPixelFormats) {
              CFIndex count = CFArrayGetCount(supportedPixelFormats);
              LOG_INFO("Decoder supports %ld pixel format(s)", (long)count);
              
              // Check if our requested format is supported
              bool requestedFormatSupported = false;
              for (CFIndex i = 0; i < count; i++) {
                  CFNumberRef formatNum = (CFNumberRef)CFArrayGetValueAtIndex(supportedPixelFormats, i);
                  if (formatNum) {
                      int32_t fmt;
                      if (CFNumberGetValue(formatNum, kCFNumberSInt32Type, &fmt)) {
                          if (fmt == pixelFormat) {
                              requestedFormatSupported = true;
                              LOG_INFO("Requested pixel format (32BGRA) is supported");
                              break;
                          }
                      }
                  }
              }
              
              if (!requestedFormatSupported) {
                  LOG_WARNING("Requested pixel format (32BGRA) may not be natively supported");
              }
              
              CFRelease(supportedPixelFormats);
          } else {
              LOG_WARNING("Could not query supported pixel formats: %d", (int)queryStatus);
          }

          // Initialize Metal Texture Cache if not already done
          if (!textureCache) {
              void* device = MTLCreateSystemDefaultDevice();
              if (device) {
                  CVReturn cvRet = CVMetalTextureCacheCreate(
                      kCFAllocatorDefault,
                      NULL,
                      (CFTypeRef)device,
                      NULL,
                      &textureCache);
                  
                  if (cvRet == kCVReturnSuccess && textureCache) {
                      LOG_INFO("Metal texture cache initialized successfully for zero-copy GPU upload");
                  } else {
                      LOG_WARNING("Failed to create Metal texture cache (error: %d), using CPU path", cvRet);
                      textureCache = nullptr;
                  }
                  CFRelease((CFTypeRef)device);
              } else {
                  LOG_INFO("Metal not available on this device, using CPU path");
              }
          }
          
          LOG_INFO("VideoToolbox decoder initialized successfully for codec: %s (hardware accelerated)",
                   codecType == kCMVideoCodecType_JPEG ? "JPEG" : 
                   (codecType == kCMVideoCodecType_AppleProRes422 ? "ProRes422" : "Unknown"));
          return true;
      }
  }

  static void decodeFrame(void *decompressionOutputRefCon,
                          void *sourceFrameRefCon,
                          OSStatus status,
                          VTDecodeInfoFlags infoFlags,
                          CVImageBufferRef pixelBuffer,
                          CMTime presentationTimeStamp,
                          CMTime presentationDuration) {
      (void)decompressionOutputRefCon;
      (void)presentationTimeStamp;
      (void)presentationDuration;
      
      if (status == noErr && pixelBuffer != NULL) {
          CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *) sourceFrameRefCon;
          // Retain the pixel buffer for the caller with proper ownership
          *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
          
          // Log hardware decode if applicable
          if (infoFlags & kVTDecodeInfo_Asynchronous) {
              // Decoding was asynchronous (hardware)
          }
      } else if (status != noErr) {
          // Decode error - output buffer remains NULL
          LOG_ERROR("Decode frame callback error: %d", (int)status);
      }
  }
};

VTRgbPacketProcessor::VTRgbPacketProcessor()
    : RgbPacketProcessor ()
    , impl_(new VTRgbPacketProcessorImpl())
{
}

VTRgbPacketProcessor::~VTRgbPacketProcessor()
{
  delete impl_;
}

void VTRgbPacketProcessor::process(const RgbPacket &packet)
{
  if (listener_ != 0) {
    @autoreleasepool {
      impl_->startTiming();

      // Create block buffer with error checking
      CMBlockBufferRef blockBuffer = nullptr;
      OSStatus status = CMBlockBufferCreateWithMemoryBlock(
          kCFAllocatorDefault,
          packet.jpeg_buffer,
          packet.jpeg_buffer_length,
          kCFAllocatorNull,
          NULL,
          0,
          packet.jpeg_buffer_length,
          0,
          &blockBuffer);
      
      if (status != noErr || !blockBuffer) {
          LOG_ERROR("CMBlockBufferCreateWithMemoryBlock failed: %d", (int)status);
          impl_->stopTiming(LOG_INFO);
          return;
      }
      
      // Create sample buffer with error checking
      CMSampleBufferRef sampleBuffer = nullptr;
      status = CMSampleBufferCreate(
          kCFAllocatorDefault,
          blockBuffer,
          true,
          NULL,
          NULL,
          impl_->format,
          1,
          0,
          NULL,
          0,
          NULL,
          &sampleBuffer);
      
      if (status != noErr || !sampleBuffer) {
          LOG_ERROR("CMSampleBufferCreate failed: %d", (int)status);
          CFRelease(blockBuffer);
          impl_->stopTiming(LOG_INFO);
          return;
      }
      
      // Attempt 1: Decode with current decoder (usually JPEG)
      CVPixelBufferRef pixelBuffer = nullptr;
      VTDecodeFrameFlags decodeFlags = 0;
      status = VTDecompressionSessionDecodeFrame(
          impl_->decoder, 
          sampleBuffer, 
          decodeFlags, 
          &pixelBuffer, 
          NULL);

      // Fallback to ProRes if JPEG decode failed
      if ((status != noErr || pixelBuffer == NULL) && impl_->currentCodec == kCMVideoCodecType_JPEG) {
          LOG_WARNING("JPEG decode failed (status=%d), attempting ProRes fallback", (int)status);
          
          // Try to reinitialize with ProRes codec
          if (impl_->setupDecoder(kCMVideoCodecType_AppleProRes422)) {
              // Re-create SampleBuffer with new format
              CFRelease(sampleBuffer);
              sampleBuffer = nullptr;
              
              status = CMSampleBufferCreate(
                  kCFAllocatorDefault,
                  blockBuffer,
                  true,
                  NULL,
                  NULL,
                  impl_->format,
                  1,
                  0,
                  NULL,
                  0,
                  NULL,
                  &sampleBuffer);
              
              if (status == noErr && sampleBuffer) {
                  // Attempt 2 with ProRes decoder
                  status = VTDecompressionSessionDecodeFrame(
                      impl_->decoder, 
                      sampleBuffer, 
                      decodeFlags, 
                      &pixelBuffer, 
                      NULL);
                      
                  if (status != noErr || pixelBuffer == NULL) {
                      LOG_ERROR("ProRes fallback also failed: %d", (int)status);
                  }
              } else {
                  LOG_ERROR("Failed to recreate sample buffer for ProRes: %d", (int)status);
              }
          } else {
              LOG_ERROR("Failed to setup ProRes decoder");
          }
      }

      if (status == noErr && pixelBuffer != NULL) {
          // Create VTFrame with Metal texture cache for potential zero-copy GPU upload
          Frame *frame = new VTFrame(1920, 1080, 4, pixelBuffer, impl_->textureCache);
          frame->format = Frame::BGRX;

          frame->timestamp = packet.timestamp;
          frame->sequence = packet.sequence;
          frame->exposure = packet.exposure;
          frame->gain = packet.gain;
          frame->gamma = packet.gamma;

          if (!listener_->onNewFrame(Frame::Color, frame)) {
              // The listener didn't take ownership of the frame, so we delete it
              delete frame;
          }
          
          // pixelBuffer is released by VTFrame destructor
      } else {
          LOG_ERROR("Failed to decode frame: status=%d", (int)status);
      }

      // Clean up resources within autoreleasepool
      if (sampleBuffer) {
          CFRelease(sampleBuffer);
      }
      if (blockBuffer) {
          CFRelease(blockBuffer);
      }

      impl_->stopTiming(LOG_INFO);
    }
  }
}

} /* namespace libfreenect2 */
