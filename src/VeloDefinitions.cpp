#include "VeloDefinitions.h"
#include "Logger.h"

VeloRawEvent::VeloRawEvent(
  const char* event
) {
  const char* p = event;
  number_of_raw_banks = *((uint32_t*)p); p += sizeof(uint32_t);
  raw_bank_offset = (uint32_t*) p; p += (number_of_raw_banks + 1) * sizeof(uint32_t);
  payload = (char*) p;
}

VeloRawBank::VeloRawBank(
  const char* raw_bank
) {
  const char* p = raw_bank;
  sensor_index = *((uint32_t*)p); p += sizeof(uint32_t);
  sp_count = *((uint32_t*)p); p += sizeof(uint32_t);
  sp_word = (uint32_t*) p;
}

VeloGeometry::VeloGeometry(const std::vector<char>& geometry) {
  const char* p = geometry.data();

  number_of_sensors            = *((uint32_t*)p); p += sizeof(uint32_t);
  number_of_sensor_columns     = *((uint32_t*)p); p += sizeof(uint32_t);
  number_of_sensors_per_module = *((uint32_t*)p); p += sizeof(uint32_t);
  chip_columns     = *((uint32_t*)p); p += sizeof(uint32_t);
  local_x          = (double*) p; p += sizeof(double) * number_of_sensor_columns;
  x_pitch          = (double*) p; p += sizeof(double) * number_of_sensor_columns;
  pixel_size       = *((float*)p); p += sizeof(float);
  ltg              = (float*) p; p += sizeof(float) * 16 * number_of_sensors;

  size = p - geometry.data();

  if (size != geometry.size()) {
    error_cout << "Size mismatch for geometry" << std::endl;
  }
}

uint32_t get_channel_id(unsigned int sensor, unsigned int chip, unsigned int col, unsigned int row)
{
  return (sensor << LHCb_VPChannelID_sensorBits) | (chip << LHCb_VPChannelID_chipBits) |
         (col << LHCb_VPChannelID_colBits) | row;
}

uint32_t get_lhcb_id(uint32_t cid)
{
  return (LHCb_VPChannelID_VP << LHCb_detectorTypeBits) + cid;
}
