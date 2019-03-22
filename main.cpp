#include "ClusteringDefinitions.h"
#include "InputTools.h"
#include "InputReader.h"
#include "ClusteringCommon.h"
#include "VeloDefinitions.h"
#include "VeloEventModel.h"
#include "AlignedAllocator.h"
#include "GlobalEventCut.h"
#include "VPClus.h"
#include "VSPClus.h"
#include "Timer.h"
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>
#include <thread>
#include <bitset>

// #define DEBUG_AMPLXE
// #define PROFILE_CALLGRIND

#ifdef PROFILE_CALLGRIND
#include <valgrind/callgrind.h>
#endif

// Include the header file that the ispc compiler generates
// #include "EstimateInputSize_ispc.h"
// #include "ispc/VeloReconstruction_ispc.h"
#include "calculate_phi_and_sort/CalculatePhiAndSort_ispc.h"
#include "fill_candidates/FillCandidates_ispc.h"
#include "search_by_triplet/SearchByTriplet_ispc.h"
#include "weak_tracks_adder/WeakTracksAdder_ispc.h"
using namespace ispc;

aligned_vector<uint32_t> dev_estimated_input_size;
aligned_vector<uint32_t> dev_module_cluster_num;
aligned_vector<int32_t> dev_atomics_velo;
aligned_vector<Velo::TrackHits> dev_tracks;

aligned_vector<uint32_t> dev_module_candidate_num;
aligned_vector<uint32_t> dev_cluster_candidates;
aligned_vector<int16_t> dev_h0_candidates;
aligned_vector<int16_t> dev_h2_candidates;

aligned_vector<Velo::TrackletHits> dev_tracklets;
aligned_vector<Velo::TrackletHits> dev_tracks_to_follow;
aligned_vector<Velo::TrackletHits> dev_weak_tracks;
aligned_vector<uint8_t> dev_hit_used;
aligned_vector<uint16_t> dev_rel_indices;

// thread_local aligned_vector<uint32_t> dev_velo_cluster_container;
aligned_vector<float> dev_velo_cluster_x;
aligned_vector<float> dev_velo_cluster_y;
aligned_vector<float> dev_velo_cluster_z;
aligned_vector<uint32_t> dev_velo_cluster_id;
aligned_vector<float> dev_velo_cluster_phi;
aligned_vector<uint32_t> dev_velo_cluster_temp;

int main()
{
  const uint number_of_events = 10;
  logger::ll.verbosityLevel = logger::info;

  aligned_vector<char> dev_velo_raw_input;
  aligned_vector<char> dev_ut_raw_input;
  aligned_vector<char> dev_scifi_raw_input;
  aligned_vector<uint32_t> dev_velo_raw_input_offsets;
  aligned_vector<uint32_t> dev_ut_raw_input_offsets;
  aligned_vector<uint32_t> dev_scifi_raw_input_offsets;

  // Read events
  std::string folder_name_raw = "../input/minbias/banks/";
  std::string folder_name_detector_configuration = "../input/detector_configuration/";

  const auto folder_name_velopix_raw = folder_name_raw + "VP";
  const auto folder_name_UT_raw = folder_name_raw + "UT";
  const auto folder_name_SciFi_raw = folder_name_raw + "FTCluster";

  info_cout << "Reading files" << std::endl;
  read_folder(folder_name_velopix_raw, number_of_events, dev_velo_raw_input, dev_velo_raw_input_offsets, 0);
  read_folder(folder_name_UT_raw, number_of_events, dev_ut_raw_input, dev_ut_raw_input_offsets, 0);
  read_folder(folder_name_SciFi_raw, number_of_events, dev_scifi_raw_input, dev_scifi_raw_input_offsets, 0);
  info_cout << std::endl;

  const auto geometry_reader = GeometryReader(folder_name_detector_configuration);
  const auto velo_geometry_p = geometry_reader.read_geometry("velo_geometry.bin");
  const VeloGeometry velo_geometry {velo_geometry_p};

  // Constants
  const std::array<uint8_t, 9> dev_velo_candidate_ks = {0, 0, 1, 4, 4, 5, 5, 5, 5};
  const std::array<float, Velo::Constants::n_modules> dev_velo_module_zs = \
    {-287.5, -275, -262.5, -250, -237.5, -225, -212.5, \
    -200, -137.5, -125, -62.5, -50, -37.5, -25, -12.5, 0, 12.5, 25, 37.5, 50, 62.5, 75, 87.5, 100, \
    112.5, 125, 137.5, 150, 162.5, 175, 187.5, 200, 212.5, 225, 237.5, 250, 262.5, 275, 312.5, 325, \
    387.5, 400, 487.5, 500, 587.5, 600, 637.5, 650, 687.5, 700, 737.5, 750};
  aligned_vector<uint8_t> sp_patterns (256, 0);
  aligned_vector<uint8_t> sp_sizes (256, 0);
  aligned_vector<float> sp_fx (512, 0);
  aligned_vector<float> sp_fy (512, 0);
  cache_sp_patterns(sp_patterns, sp_sizes, sp_fx, sp_fy);

  uint8_t _linkNS[256];
  for (int data=0 ; data<256 ; data++) {
    std::bitset<8> sp(data);
    _linkNS[data] = (sp[4] && (sp[0] || sp[1])) ||
                    (sp[5] && (sp[0] || sp[1] || sp[2])) ||
                    (sp[6] && (sp[1] || sp[2] || sp[3])) ||
                    (sp[7] && (sp[2] || sp[3]));
  }

  // Timer t_clustering, t_tracking;

  uint number_of_selected_events = 0u;

#ifdef PROFILE_CALLGRIND
  CALLGRIND_TOGGLE_COLLECT;
#endif
  uint total_number_of_velo_clusters;

  // Resizes are here to maintain thread-safety.
  // Time spent in resizing if the size is the same is zero anyway.
  dev_estimated_input_size.resize(number_of_events * Velo::Constants::n_modules + 1);
  dev_module_cluster_num.resize(number_of_events * Velo::Constants::n_modules);
  dev_tracks.resize(number_of_events * Velo::Constants::max_tracks);
  dev_atomics_velo.resize(number_of_events * Velo::num_atomics);

  // Estimate input size
  std::fill(dev_estimated_input_size.begin(), dev_estimated_input_size.end(), 0);
  std::fill(dev_module_cluster_num.begin(), dev_module_cluster_num.end(), 0);

  dev_module_candidate_num.resize(number_of_events);
  dev_cluster_candidates.resize(number_of_events * VeloClustering::max_candidates_event);

  std::fill(dev_module_candidate_num.begin(), dev_module_candidate_num.end(), 0);

  // Global event cut
  aligned_vector<uint32_t> dev_event_list;
  global_event_cut(
                   dev_ut_raw_input,
                   dev_ut_raw_input_offsets,
                   dev_scifi_raw_input,
                   dev_scifi_raw_input_offsets,
                   dev_event_list,
                   number_of_events);
  number_of_selected_events = dev_event_list.size();

  // t_clustering.start();

  // Empty the vectors
  dev_velo_cluster_x.clear();
  dev_velo_cluster_y.clear();
  dev_velo_cluster_z.clear();
  dev_velo_cluster_id.clear();
  dev_velo_cluster_temp.clear();

  dev_velo_cluster_x.reserve(10000U * number_of_events);
  dev_velo_cluster_y.reserve(10000U * number_of_events);
  dev_velo_cluster_z.reserve(10000U * number_of_events);
  dev_velo_cluster_id.reserve(10000U * number_of_events);
  dev_velo_cluster_temp.reserve(10000U * number_of_events);

  vsp_clustering(
                 _linkNS,
                 sp_patterns,
                 sp_sizes,
                 sp_fx,
                 sp_fy,
                 velo_geometry,
                 dev_velo_raw_input,
                 dev_velo_raw_input_offsets,
                 dev_estimated_input_size,
                 dev_module_cluster_num,
                 dev_velo_cluster_x,
                 dev_velo_cluster_y,
                 dev_velo_cluster_z,
                 dev_velo_cluster_id,
                 dev_velo_cluster_phi,
                 dev_velo_cluster_temp,
                 dev_event_list,
                 number_of_selected_events);

  dev_velo_cluster_phi.resize(dev_velo_cluster_x.size());
  // dev_velo_cluster_temp.resize(dev_velo_cluster_x.size());

  // Prefix sum
  int32_t accumulated = 0;
  for (size_t i=0; i<dev_module_cluster_num.size(); ++i) {
    dev_estimated_input_size[i] = accumulated;
    accumulated += dev_module_cluster_num[i];
  }
  dev_estimated_input_size[dev_estimated_input_size.size() - 1] = accumulated;
  total_number_of_velo_clusters = accumulated;

  // Calculate phi and sort
  for (uint32_t i = 0; i < number_of_selected_events; ++i) {
    const uint32_t event_number = i;
    calculate_phi_and_sort(
                           reinterpret_cast<uint32_t*>(dev_estimated_input_size.data()),
                           reinterpret_cast<uint32_t*>(dev_module_cluster_num.data()),
                           reinterpret_cast<float*>(dev_velo_cluster_x.data()),
                           reinterpret_cast<float*>(dev_velo_cluster_y.data()),
                           reinterpret_cast<float*>(dev_velo_cluster_z.data()),
                           reinterpret_cast<uint32_t*>(dev_velo_cluster_id.data()),
                           reinterpret_cast<float*>(dev_velo_cluster_phi.data()),
                           reinterpret_cast<uint32_t*>(dev_velo_cluster_temp.data()),
                           event_number,
                           number_of_selected_events);
  }

  // Fill candidates
  dev_h0_candidates.resize(2 * total_number_of_velo_clusters);
  dev_h2_candidates.resize(2 * total_number_of_velo_clusters);
  std::fill(dev_h0_candidates.begin(), dev_h0_candidates.end(), -1);
  std::fill(dev_h2_candidates.begin(), dev_h2_candidates.end(), -1);

  for (uint32_t i = 0; i < number_of_selected_events; ++i) {
    const uint32_t event_number = i;
    fill_candidates(
                    reinterpret_cast<float*>(dev_velo_cluster_x.data()),
                    reinterpret_cast<float*>(dev_velo_cluster_y.data()),
                    reinterpret_cast<float*>(dev_velo_cluster_z.data()),
                    reinterpret_cast<uint32_t*>(dev_velo_cluster_id.data()),
                    reinterpret_cast<float*>(dev_velo_cluster_phi.data()),
                    reinterpret_cast<uint32_t*>(dev_velo_cluster_temp.data()),
                    reinterpret_cast<uint32_t*>(dev_estimated_input_size.data()),
                    reinterpret_cast<uint32_t*>(dev_module_cluster_num.data()),
                    reinterpret_cast<int16_t*>(dev_h0_candidates.data()),
                    reinterpret_cast<int16_t*>(dev_h2_candidates.data()),
                    event_number,
                    number_of_selected_events);
  }

  // Search by triplet
  std::fill(dev_atomics_velo.begin(), dev_atomics_velo.end(), 0);

  dev_tracklets.resize(number_of_selected_events * Velo::Tracking::ttf_modulo);
  dev_tracks_to_follow.resize(number_of_selected_events * Velo::Tracking::ttf_modulo);
  dev_weak_tracks.resize(number_of_selected_events * Velo::Tracking::max_weak_tracks);
  dev_hit_used.resize(total_number_of_velo_clusters);
  dev_rel_indices.resize(number_of_selected_events * 2 * Velo::Constants::max_numhits_in_module);

  std::fill(dev_hit_used.begin(), dev_hit_used.end(), 0);

  for (uint32_t i = 0; i < number_of_selected_events; ++i) {
    const uint32_t event_number = i;
    search_by_triplet(
                      reinterpret_cast<float*>(dev_velo_cluster_x.data()),
                      reinterpret_cast<float*>(dev_velo_cluster_y.data()),
                      reinterpret_cast<float*>(dev_velo_cluster_z.data()),
                      reinterpret_cast<uint32_t*>(dev_velo_cluster_id.data()),
                      reinterpret_cast<float*>(dev_velo_cluster_phi.data()),
                      reinterpret_cast<uint32_t*>(dev_velo_cluster_temp.data()),
                      reinterpret_cast<uint32_t*>(dev_estimated_input_size.data()),
                      reinterpret_cast<uint32_t*>(dev_module_cluster_num.data()),
                      reinterpret_cast<int8_t*>(dev_tracks.data()),
                      reinterpret_cast<int8_t*>(dev_tracklets.data()),
                      reinterpret_cast<uint32_t*>(dev_tracks_to_follow.data()),
                      reinterpret_cast<int8_t*>(dev_weak_tracks.data()),
                      reinterpret_cast<int8_t*>(dev_hit_used.data()),
                      reinterpret_cast<int32_t*>(dev_atomics_velo.data()),
                      reinterpret_cast<int16_t*>(dev_h0_candidates.data()),
                      reinterpret_cast<int16_t*>(dev_h2_candidates.data()),
                      reinterpret_cast<uint16_t*>(dev_rel_indices.data()),
                      reinterpret_cast<const float*>(dev_velo_module_zs.data()),
                      event_number,
                      number_of_selected_events);
  }

#ifdef DEBUG_AMPLXE
  __itt_resume();
#endif

  for (uint32_t i = 0; i < number_of_selected_events; ++i) {
    const uint32_t event_number = i;
    weak_tracks_adder(
                      reinterpret_cast<float*>(dev_velo_cluster_x.data()),
                      reinterpret_cast<float*>(dev_velo_cluster_y.data()),
                      reinterpret_cast<float*>(dev_velo_cluster_z.data()),
                      reinterpret_cast<uint32_t*>(dev_velo_cluster_id.data()),
                      reinterpret_cast<float*>(dev_velo_cluster_phi.data()),
                      reinterpret_cast<uint32_t*>(dev_velo_cluster_temp.data()),
                      reinterpret_cast<uint32_t*>(dev_estimated_input_size.data()),
                      reinterpret_cast<int8_t*>(dev_tracks.data()),
                      reinterpret_cast<int8_t*>(dev_weak_tracks.data()),
                      reinterpret_cast<int8_t*>(dev_hit_used.data()),
                      reinterpret_cast<int32_t*>(dev_atomics_velo.data()),
                      event_number,
                      number_of_selected_events);
  }

#ifdef DEBUG_AMPLXE
  __itt_pause();
#endif

#ifdef PROFILE_CALLGRIND
  CALLGRIND_TOGGLE_COLLECT;
#endif

  Timer t;

#ifdef PROFILE_CALLGRIND
  CALLGRIND_DUMP_STATS;
#endif

  info_cout << number_of_events << " " << number_of_selected_events << std::endl;

  // NOTE: Use these pointers, the "dev_" containers are badly named.
  const float* hit_Xs = (float*) (dev_velo_cluster_temp.data());
  const float* hit_Ys = (float*) (dev_velo_cluster_x.data());
  const float* hit_Zs = (float*) (dev_velo_cluster_y.data());
  const float* hit_Phis = (float*) (dev_velo_cluster_phi.data());
  const uint32_t* hit_IDs = (uint32_t*) (dev_velo_cluster_z.data());

  info_cout << "Found tracks:" << std::endl;
  for (int i = 0; i < number_of_selected_events; ++i) {
    info_cout << "Event#" << i << " " << dev_atomics_velo[i] << std::endl;
  }
  info_cout << std::endl;

  for (int i = 0; i < number_of_selected_events; ++i) {
    int n_tracks = dev_atomics_velo[i];
    info_cout << "Event #" << i << " " << n_tracks << std::endl;
    // Offsets to the parts in the container that belong to events
    const unsigned int hit_offset = dev_estimated_input_size[i * Velo::Constants::n_modules];
    const unsigned int tracks_offset = i * Velo::Constants::max_tracks;

    for (int j = 0; j < n_tracks; ++j) {
      info_cout << "Track #" << j << std::endl;
      const Velo::TrackHits& track_hits = dev_tracks[tracks_offset + j];
      for (int k = 0; k < track_hits.hitsNum; ++k) {
        const short hitno = track_hits.hits[k];
        info_cout << " {"
                  << hit_Xs[hit_offset + hitno] << ", "
                  << hit_Ys[hit_offset + hitno] << ", "
                  << hit_Zs[hit_offset + hitno] << ", "
                  << hit_IDs[hit_offset + hitno] << "}" << std::endl;
      }
      info_cout << std::endl;
    }
  }

  // Part 2
  // Prepare tracks for checking and check them using the CheckerInvoker
  // Some hints:
  // - the mc_folder data files are in input/minbias/MC_info/tracks
  // - the number of requested events is 10
  // - the event list contains all selected events

  return 0;
}
