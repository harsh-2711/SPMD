#include "ProcessModules.ispc"

/**
 * @brief Track forwarding algorithm based on triplet finding
 */
export void search_by_triplet(
  uniform float dev_velo_cluster_x [],
  uniform float dev_velo_cluster_y [],
  uniform float dev_velo_cluster_z [],
  uniform unsigned int32 dev_velo_cluster_id [],
  uniform float dev_velo_cluster_phi [],
  uniform unsigned int32 dev_velo_cluster_temp [],
  uniform unsigned int32 dev_module_cluster_start [],
  uniform unsigned int32 dev_module_cluster_num [],
  uniform int8 dev_tracks_param [],
  uniform int8 dev_tracklets_param [],
  uniform unsigned int32 dev_tracks_to_follow [],
  uniform int8 dev_weak_tracks_param [],
  uniform int8 dev_hit_used [],
  uniform int32 dev_atomics_velo [],
  uniform int16 dev_h0_candidates [],
  uniform int16 dev_h2_candidates [],
  uniform unsigned int16 dev_rel_indices [],
  uniform const float dev_velo_module_zs [],
  uniform const unsigned int32 event_number,
  uniform const unsigned int32 number_of_events)
{
  uniform Velo_TrackHits* dev_tracks = (Velo_TrackHits*) dev_tracks_param;
  uniform Velo_TrackletHits* dev_tracklets = (Velo_TrackletHits*) dev_tracklets_param;
  uniform Velo_TrackletHits* dev_weak_tracks = (Velo_TrackletHits*) dev_weak_tracks_param;

  // Each event is treated with two blocks, one for each side.
  const unsigned int32 tracks_offset = event_number * Velo_Constants_max_tracks;

  // Pointers to data within the event
  uniform const unsigned int32 number_of_hits = dev_module_cluster_start[Velo_Constants_n_modules * number_of_events];
  uniform const unsigned int32* uniform module_hitStarts = dev_module_cluster_start + event_number * Velo_Constants_n_modules;
  uniform const unsigned int32* uniform module_hitNums = dev_module_cluster_num + event_number * Velo_Constants_n_modules;
  uniform const unsigned int32 hit_offset = module_hitStarts[0];
  // assert((module_hitStarts[52] - module_hitStarts[0]) < Velo_Constants_max_number_of_hits_per_event);
  
  // Order has changed since SortByPhi
  const float* hit_Ys = (float*) (dev_velo_cluster_x + hit_offset);
  const float* hit_Zs = (float*) (dev_velo_cluster_y + hit_offset);
  const float* hit_Phis = (float*) (dev_velo_cluster_phi + hit_offset);
  const float* hit_Xs = (float*) (dev_velo_cluster_temp + hit_offset);
  // const float* hit_IDs = (float*) (dev_velo_cluster_container + 2 * number_of_hits + hit_offset);

  // Per event datatypes
  Velo_TrackHits* tracks = dev_tracks + tracks_offset;
  unsigned int32* tracks_insert_pointer = (unsigned int32*) dev_atomics_velo + event_number;

  // Per side datatypes
  int8* hit_used = dev_hit_used + hit_offset;
  int16* h0_candidates = dev_h0_candidates + 2*hit_offset;
  int16* h2_candidates = dev_h2_candidates + 2*hit_offset;

  unsigned int32* tracks_to_follow = dev_tracks_to_follow + event_number * Velo_Tracking_ttf_modulo;
  Velo_TrackletHits* weak_tracks = dev_weak_tracks + event_number * Velo_Tracking_max_weak_tracks;
  Velo_TrackletHits* tracklets = dev_tracklets + event_number * Velo_Tracking_ttf_modulo;
  unsigned int16* h1_rel_indices = dev_rel_indices + event_number * Velo_Constants_max_numhits_in_module;

  // Initialize variables according to event number and module side
  // Insert pointers (atomics)
  uniform const int ip_shift = number_of_events + event_number * (Velo_num_atomics - 1);
  unsigned int32* weaktracks_insert_pointer = (unsigned int32*) dev_atomics_velo + ip_shift;
  unsigned int32* tracklets_insert_pointer = (unsigned int32*) dev_atomics_velo + ip_shift + 1;
  uniform unsigned int32* uniform ttf_insert_pointer = (unsigned int32*) dev_atomics_velo + ip_shift + 2;
  uniform unsigned int32* uniform local_number_of_hits = (unsigned int32*) dev_atomics_velo + ip_shift + 3;

  // "Shared memory"
  uniform Velo_Module module_data [6];
  
  // Process modules
  process_modules(
    module_data,
    Velo_Constants_n_modules-1,
    2,
    hit_used,
    h0_candidates,
    h2_candidates,
    Velo_Constants_n_modules,
    module_hitStarts,
    module_hitNums,
    hit_Xs,
    hit_Ys,
    hit_Zs,
    hit_Phis,
    weaktracks_insert_pointer,
    tracklets_insert_pointer,
    ttf_insert_pointer,
    tracks_insert_pointer,
    tracks_to_follow,
    weak_tracks,
    tracklets,
    tracks,
    number_of_hits,
    h1_rel_indices,
    local_number_of_hits,
    hit_offset,
    dev_velo_module_zs
  );
}
