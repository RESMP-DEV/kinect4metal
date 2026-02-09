#ifndef LIBFREENECT2_METAL_DEPTH_PACKET_PROCESSOR_H
#define LIBFREENECT2_METAL_DEPTH_PACKET_PROCESSOR_H

#include <libfreenect2/depth_packet_processor.h>

namespace libfreenect2 {

class MetalDepthPacketProcessorImpl;

class MetalDepthPacketProcessor : public DepthPacketProcessor {
public:
  MetalDepthPacketProcessor(int deviceId = -1);
  virtual ~MetalDepthPacketProcessor();
  
  virtual void setConfiguration(const libfreenect2::Freenect2Device::Config &config);
  virtual void loadP0TablesFromCommandResponse(unsigned char *buffer, size_t buffer_length);
  virtual void loadXZTables(const float *xtable, const float *ztable);
  virtual void loadLookupTable(const short *lut);
  virtual bool ready();
  virtual void process(const DepthPacket &packet);
  virtual const char *name();
  
private:
  MetalDepthPacketProcessorImpl *impl_;
};

} // namespace libfreenect2

#endif
