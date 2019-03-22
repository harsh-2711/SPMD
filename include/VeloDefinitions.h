#pragma once

#include <cstdint>
#include "AlignedAllocator.h"

constexpr static uint32_t LHCb_VPChannelID_colBits = 8;
constexpr static uint32_t LHCb_VPChannelID_chipBits = 16;
constexpr static uint32_t LHCb_VPChannelID_sensorBits = 18;
constexpr static uint32_t LHCb_VPChannelID_VP = 8;
constexpr static uint32_t LHCb_detectorTypeBits = 28;

namespace Velo {
  // Total number of atomics required
  static constexpr unsigned int num_atomics = 5;

  namespace Constants {

    // Detector constants
    static constexpr unsigned int n_modules = 52;
    static constexpr unsigned int n_sensors = n_modules * 4;
    static constexpr float z_endVelo = 770;

    // Constant for maximum number of hits in a module
    static constexpr unsigned int max_numhits_in_module = 500;

    // High number of hits per event
    static constexpr unsigned int max_number_of_hits_per_event = 9500;

    // Constants for requested storage on device
    static constexpr unsigned int max_tracks = 1200;
    static constexpr unsigned int max_track_size = 26;

  } // namespace Constants

  namespace Tracking {
    // How many concurrent h1s to process max
    // It should be a divisor of NUMTHREADS_X
    static constexpr unsigned int max_concurrent_h1 = 16;

    // Number of concurrent h1s in the first iteration
    // The first iteration has no flagged hits and more triplets per hit
    static constexpr unsigned int max_concurrent_h1_first_iteration = 8;

    // These parameters impact the found tracks
    // Maximum / minimum acceptable phi
    // This impacts enourmously the speed of track seeding
    // static constexpr float phi_extrapolation = 0.0436332f;
    static constexpr float phi_extrapolation = 0.062f;
    // static constexpr float phi_extrapolation = 0.0959931f;

    // Forward tolerance in phi
    constexpr float forward_phi_tolerance = 0.052f;

    // Tolerance angle for forming triplets
    static constexpr float max_slope = 0.4f;
    static constexpr float tolerance = 0.6f;

    // Maximum scatter of each three hits
    // This impacts velo tracks and a to a lesser extent
    // long and long strange tracks
    static constexpr float max_scatter_seeding = 0.004f;

    // Making a bigger forwarding scatter window causes
    // less clones and more ghosts
    static constexpr float max_scatter_forwarding = 0.004f;
    // Maximum number of skipped modules allowed for a track
    // before storing it
    static constexpr unsigned int max_skipped_modules = 1;

    // Maximum number of tracks to follow at a time
    static constexpr unsigned int ttf_modulo = 2000;
    static constexpr unsigned int max_weak_tracks = 500;

    // Constants for filters
    static constexpr unsigned int states_per_track = 3;
    static constexpr float param_w = 3966.94f;
    static constexpr float param_w_inverted = 0.000252083f;

    // Max chi2
    static constexpr float max_chi2 = 20.0;

  } // namespace Tracking
} // namespace Velo

struct VeloGeometry {
  uint32_t size;
  uint32_t number_of_sensors;
  uint32_t number_of_sensor_columns;
  uint32_t number_of_sensors_per_module;
  uint32_t chip_columns;
  float pixel_size;
  double* local_x;
  double* x_pitch;
  float* ltg;

  /**
   * @brief Typecast from std::vector.
   */
  VeloGeometry(const std::vector<char>& geometry);
};

struct VeloRawEvent {
  uint32_t number_of_raw_banks;
  uint32_t* raw_bank_offset;
  char* payload;

  VeloRawEvent(
    const char* event
  );
};

struct VeloRawBank {
  uint32_t sensor_index;
  uint32_t sp_count;
  uint32_t* sp_word;

  VeloRawBank(
    const char* raw_bank
  );
};

uint32_t get_channel_id(unsigned int sensor, unsigned int chip, unsigned int col, unsigned int row);

int32_t get_lhcb_id(int32_t cid);
