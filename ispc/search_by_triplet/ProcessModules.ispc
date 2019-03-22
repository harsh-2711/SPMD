#include "utils/BinarySearchFirstCandidate.ih"
#include "TrackSeeding.ispc"
#include "TrackForwarding.ispc"

/**
 * @brief Processes modules in decreasing order with some stride
 */
void process_modules(
  uniform Velo_Module* uniform module_data,
  uniform const unsigned int32 starting_module,
  uniform const unsigned int32 stride,
  uniform int8* hit_used,
  uniform const int16* h0_candidates,
  uniform const int16* h2_candidates,
  uniform const unsigned int32 number_of_modules,
  uniform const unsigned int32* module_hitStarts,
  uniform const unsigned int32* module_hitNums,
  uniform const float* hit_Xs,
  uniform const float* hit_Ys,
  uniform const float* hit_Zs,
  uniform const float* hit_Phis,
  uniform unsigned int32* weaktracks_insert_pointer,
  uniform unsigned int32* tracklets_insert_pointer,
  uniform unsigned int32* uniform ttf_insert_pointer,
  uniform unsigned int32* tracks_insert_pointer,
  uniform unsigned int32* tracks_to_follow,
  uniform Velo_TrackletHits* weak_tracks,
  uniform Velo_TrackletHits* tracklets,
  uniform Velo_TrackHits* tracks,
  uniform const unsigned int32 number_of_hits,
  uniform unsigned int16* h1_rel_indices,
  uniform unsigned int32* uniform local_number_of_hits,
  uniform const unsigned int32 hit_offset,
  uniform const float* dev_velo_module_zs
) {
  uniform unsigned int32 first_module = starting_module;

  // Prepare the first seeding iteration
  // Load shared module information
  foreach (i = 0 ... 6) {
    const unsigned int32 module_number = first_module - i;
    module_data[i].hitStart = module_hitStarts[module_number] - hit_offset;
    module_data[i].hitNums = module_hitNums[module_number];
    module_data[i].z = dev_velo_module_zs[module_number];
  }

  // Due to shared module data loading
  memory_barrier();

  // Do first track seeding
  track_seeding(
    hit_Xs,
    hit_Ys,
    hit_Zs,
    module_data,
    h0_candidates,
    h2_candidates,
    hit_used,
    tracklets_insert_pointer,
    ttf_insert_pointer,
    tracklets,
    tracks_to_follow,
    h1_rel_indices,
    local_number_of_hits
  );

  // Prepare forwarding - seeding loop
  uniform unsigned int32 last_ttf = 0;
  first_module -= stride;

  while (first_module >= 4) {

    // Due to WAR between trackSeedingFirst and the code below
    memory_barrier();

    // Iterate in modules
    // Load in shared
    foreach (i = 0 ... 6) {
      const unsigned int32 module_number = first_module - i;
      module_data[i].hitStart = module_hitStarts[module_number] - hit_offset;
      module_data[i].hitNums = module_hitNums[module_number];
      module_data[i].z = dev_velo_module_zs[module_number];
    }

    uniform const unsigned int32 prev_ttf = last_ttf;
    last_ttf = ttf_insert_pointer[0];
    uniform const unsigned int32 diff_ttf = last_ttf - prev_ttf;

    // print("New tracks to follow: %i\n", diff_ttf);

    // Reset atomics
    local_number_of_hits[0] = 0;

    // Due to module data loading
    memory_barrier();

    // Track Forwarding
    track_forwarding(
      hit_Xs,
      hit_Ys,
      hit_Zs,
      hit_Phis,
      hit_used,
      tracks_insert_pointer,
      ttf_insert_pointer,
      weaktracks_insert_pointer,
      module_data,
      diff_ttf,
      tracks_to_follow,
      weak_tracks,
      prev_ttf,
      tracklets,
      tracks,
      number_of_hits
    );

    // Due to ttf_insert_pointer
    memory_barrier();

    // Seeding
    track_seeding(
      hit_Xs,
      hit_Ys,
      hit_Zs,
      module_data,
      h0_candidates,
      h2_candidates,
      hit_used,
      tracklets_insert_pointer,
      ttf_insert_pointer,
      tracklets,
      tracks_to_follow,
      h1_rel_indices,
      local_number_of_hits
    );

    first_module -= stride;
  }

  // Due to last seeding ttf_insert_pointer
  memory_barrier();

  uniform const unsigned int32 prev_ttf = last_ttf;
  last_ttf = ttf_insert_pointer[0];
  uniform const unsigned int32 diff_ttf = last_ttf - prev_ttf;

  // Process the last bunch of track_to_follows
  foreach (ttf_element = 0 ... diff_ttf) {
    const int fulltrackno = tracks_to_follow[(prev_ttf + ttf_element) % Velo_Tracking_ttf_modulo];
    const bool track_flag = (fulltrackno & 0x80000000) == 0x80000000;
    const int trackno = fulltrackno & 0x0FFFFFFF;

    // Here we are only interested in three-hit tracks,
    // to mark them as "doubtful"
    if (track_flag) {
      const unsigned int32 weakP = atomic_add_global(weaktracks_insert_pointer, 1);
      // assert(weakP < number_of_hits);
      weak_tracks[weakP] = tracklets[trackno];
    }
  }
}
