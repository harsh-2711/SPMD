#pragma once

#include <cstdint>
#include "VeloDefinitions.h"

namespace VeloClustering {
  // Adjusted to minbias events. In the future, it should
  // be adjusted on the go.
  static constexpr uint32_t max_candidates_event = 3000;

  static constexpr uint32_t mask_bottom          = 0xFFFEFFFF;
  static constexpr uint32_t mask_top             = 0xFFFF7FFF;
  static constexpr uint32_t mask_top_left        = 0x7FFF7FFF;
  static constexpr uint32_t mask_bottom_right    = 0xFFFEFFFE;
  static constexpr uint32_t mask_ltr_top_right   = 0x7FFF0000;
  static constexpr uint32_t mask_rtl_bottom_left = 0x0000FFFE;
  static constexpr uint32_t max_clustering_iterations = 12;
  static constexpr uint32_t lookup_table_size = 9;
}

namespace LHCb {
  namespace VPChannelID {
    /// Offsets of bitfield channelID
    enum channelIDBits{rowBits    = 0,
                       colBits    = 8,
                       chipBits   = 16,
                       sensorBits = 18
                     };

    /// Bitmasks for bitfield channelID
    enum channelIDMasks{rowMask    = 0xffL,
                        colMask    = 0xff00L,
                        chipMask   = 0x30000L,
                        sensorMask = 0xffc0000L
                      };

    enum channelIDtype{ Velo=1,
                        TT,
                        IT,
                        OT,
                        Rich,
                        Calo,
                        Muon,
                        VP,
                        FT=10,
                        UT,
                        HC
                      };
  }

  /// Offsets of bitfield lhcbID
  enum lhcbIDBits{IDBits           = 0,
                  detectorTypeBits = 28};
}

namespace VP {
  static constexpr unsigned int NModules = Velo::Constants::n_modules;
  static constexpr unsigned int NSensorsPerModule = 4;
  static constexpr unsigned int NSensors = NModules * NSensorsPerModule;
  static constexpr unsigned int NChipsPerSensor = 3;
  static constexpr unsigned int NRows = 256;
  static constexpr unsigned int NColumns = 256;
  static constexpr unsigned int NSensorColumns = NColumns * NChipsPerSensor;
  static constexpr unsigned int NPixelsPerSensor = NSensorColumns * NRows;
  static constexpr unsigned int ChipColumns = 256;
  static constexpr double Pitch = 0.055;
}
