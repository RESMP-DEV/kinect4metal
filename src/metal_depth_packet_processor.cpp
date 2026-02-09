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

/** @file metal_depth_packet_processor.cpp C++ wrapper for Metal depth packet processor. */

#include <libfreenect2/depth_packet_processor.h>
#include <libfreenect2/metal_depth_packet_processor.h>
#include <libfreenect2/resource.h>
#include <libfreenect2/protocol/response.h>
#include <libfreenect2/logging.h>

#include <sstream>
#include <cstring>

#define _USE_MATH_DEFINES
#include <math.h>

#ifdef __APPLE__
#include "metal_depth_processor_objc.h"
#endif

namespace libfreenect2
{

#ifdef LIBFREENECT2_WITH_METAL_SUPPORT

class MetalDepthPacketProcessorImpl
{
public:
  static const size_t IMAGE_SIZE = 512*424;
  static const size_t LUT_SIZE = 2048;

  libfreenect2::DepthPacketProcessor::Config config;
  DepthPacketProcessor::Parameters params;

  Frame *ir_frame, *depth_frame;

  // Objective-C processor wrapper
  MetalDepthPacketProcessor *processor;
  
  bool deviceInitialized;
  bool programInitialized;
  bool runtimeOk;

  MetalDepthPacketProcessorImpl(int deviceId)
    : processor(nil)
    , deviceInitialized(false)
    , programInitialized(false)
    , runtimeOk(true)
    , ir_frame(nullptr)
    , depth_frame(nullptr)
  {
    @autoreleasepool
    {
      // Create the Objective-C++ Metal processor
      processor = [[MetalDepthPacketProcessor alloc] initWithWidth:512 height:424];
      
      if (!processor || ![processor isReady]) {
        LOG_ERROR << "Failed to initialize Metal depth packet processor";
        processor = nil;
        runtimeOk = false;
        return;
      }
      
      deviceInitialized = true;
      programInitialized = true;

      // Allocate frames
      newIrFrame();
      newDepthFrame();
    }
  }
  
  ~MetalDepthPacketProcessorImpl()
  {
    @autoreleasepool
    {
      delete ir_frame;
      delete depth_frame;
      processor = nil;
    }
  }
  
  void newIrFrame()
  {
    ir_frame = new Frame(512, 424, sizeof(float));
    ir_frame->format = Frame::Float;
  }
  
  void newDepthFrame()
  {
    depth_frame = new Frame(512, 424, sizeof(float));
    depth_frame->format = Frame::Float;
  }
  
  bool ready() const
  {
    return deviceInitialized && programInitialized && runtimeOk && 
           processor != nil && [processor isReady];
  }
  
  void loadP0TablesFromCommandResponse(unsigned char *buffer, size_t buffer_length)
  {
    @autoreleasepool
    {
      if (!processor) return;
      
      [processor loadP0TablesFromCommandResponse:buffer length:buffer_length];
    }
  }
  
  void loadXZTables(const float *xtable, const float *ztable)
  {
    @autoreleasepool
    {
      if (!processor) return;
      
      [processor loadXZTables:xtable zTable:ztable length:IMAGE_SIZE];
    }
  }
  
  void loadLookupTable(const short *lut)
  {
    @autoreleasepool
    {
      if (!processor) return;
      
      // Convert short LUT to float for Metal shader
      float floatLut[LUT_SIZE];
      for (size_t i = 0; i < LUT_SIZE; ++i) {
        floatLut[i] = static_cast<float>(lut[i]);
      }
      
      [processor loadLookupTable:floatLut length:LUT_SIZE];
    }
  }
  
  void setConfiguration(const libfreenect2::DepthPacketProcessor::Config &newConfig)
  {
    config = newConfig;
  }
  
  void process(const DepthPacket &packet)
  {
    @autoreleasepool
    {
      if (!processor || !runtimeOk) return;
      
      // Create output buffer for depth data
      float *outputData = new float[IMAGE_SIZE];
      
      // Process with Metal
      [processor processDepthData:packet.buffer
                       outputTo:outputData
                   enableFilter:config.EnableEdgeAwareFilter ? YES : NO
                enableBilateral:config.EnableBilateralFilter ? YES : NO];
      
      // Copy depth results to frame
      std::memcpy(depth_frame->data, outputData, IMAGE_SIZE * sizeof(float));
      
      // For IR data, we would need a separate output or extract from intermediate results
      // For now, set IR to zero (or could implement separate IR output)
      std::memset(ir_frame->data, 0, IMAGE_SIZE * sizeof(float));
      
      delete[] outputData;
    }
  }
};

MetalDepthPacketProcessor::MetalDepthPacketProcessor(int deviceId)
  : DepthPacketProcessor()
  , impl_(nullptr)
{
  impl_ = new MetalDepthPacketProcessorImpl(deviceId);
}

MetalDepthPacketProcessor::~MetalDepthPacketProcessor()
{
  delete impl_;
}

void MetalDepthPacketProcessor::setConfiguration(const libfreenect2::Freenect2Device::Config &config)
{
  if (impl_) impl_->setConfiguration(config);
  DepthPacketProcessor::setConfiguration(config);
}

void MetalDepthPacketProcessor::loadP0TablesFromCommandResponse(unsigned char *buffer, size_t buffer_length)
{
  if (impl_) impl_->loadP0TablesFromCommandResponse(buffer, buffer_length);
}

void MetalDepthPacketProcessor::loadXZTables(const float *xtable, const float *ztable)
{
  if (impl_) impl_->loadXZTables(xtable, ztable);
}

void MetalDepthPacketProcessor::loadLookupTable(const short *lut)
{
  if (impl_) impl_->loadLookupTable(lut);
}

bool MetalDepthPacketProcessor::ready()
{
  return impl_ != nullptr && impl_->ready();
}

void MetalDepthPacketProcessor::process(const DepthPacket &packet)
{
  if (!listener_ || !impl_) return;
  
  if (!impl_->ready())
  {
    LOG_ERROR << "Metal processor not ready";
    return;
  }
  
  impl_->ir_frame->timestamp = packet.timestamp;
  impl_->depth_frame->timestamp = packet.timestamp;
  impl_->ir_frame->sequence = packet.sequence;
  impl_->depth_frame->sequence = packet.sequence;
  
  impl_->process(packet);
  
  if (listener_->onNewFrame(Frame::Ir, impl_->ir_frame))
    impl_->newIrFrame();
  if (listener_->onNewFrame(Frame::Depth, impl_->depth_frame))
    impl_->newDepthFrame();
}

const char *MetalDepthPacketProcessor::name()
{
  return "Metal";
}

#else // LIBFREENECT2_WITH_METAL_SUPPORT

class MetalDepthPacketProcessorImpl
{
public:
  MetalDepthPacketProcessorImpl(int deviceId)
  {
    LOG_ERROR << "Metal support not compiled into this binary";
  }
  
  ~MetalDepthPacketProcessorImpl() {}
  bool ready() const { return false; }
  void setConfiguration(const libfreenect2::DepthPacketProcessor::Config &) {}
  void loadP0TablesFromCommandResponse(unsigned char *, size_t) {}
  void loadXZTables(const float *, const float *) {}
  void loadLookupTable(const short *) {}
  void process(const DepthPacket &) {}
};

MetalDepthPacketProcessor::MetalDepthPacketProcessor(int deviceId)
  : DepthPacketProcessor()
  , impl_(nullptr)
{
  impl_ = new MetalDepthPacketProcessorImpl(deviceId);
}

MetalDepthPacketProcessor::~MetalDepthPacketProcessor()
{
  delete impl_;
}

void MetalDepthPacketProcessor::setConfiguration(const libfreenect2::Freenect2Device::Config &config)
{
  if (impl_) impl_->setConfiguration(config);
}

void MetalDepthPacketProcessor::loadP0TablesFromCommandResponse(unsigned char *buffer, size_t buffer_length)
{
  if (impl_) impl_->loadP0TablesFromCommandResponse(buffer, buffer_length);
}

void MetalDepthPacketProcessor::loadXZTables(const float *xtable, const float *ztable)
{
  if (impl_) impl_->loadXZTables(xtable, ztable);
}

void MetalDepthPacketProcessor::loadLookupTable(const short *lut)
{
  if (impl_) impl_->loadLookupTable(lut);
}

bool MetalDepthPacketProcessor::ready()
{
  return impl_ != nullptr && impl_->ready();
}

void MetalDepthPacketProcessor::process(const DepthPacket &packet)
{
  if (impl_) impl_->process(packet);
}

const char *MetalDepthPacketProcessor::name()
{
  return "Metal (disabled)";
}

#endif // LIBFREENECT2_WITH_METAL_SUPPORT

} // namespace libfreenect2
