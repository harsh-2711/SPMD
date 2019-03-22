#include "common/VeloCommon.ih"
#include "utils/HitPhi.ih"
#include "utils/BinarySearchFirstCandidate.ih"

/**
 * @brief Finds candidates in the specified module.
 */
void find_forward_candidates_even(
  uniform const Velo_Module& module,
  const float tx,
  const float ty,
  const float* hit_Phis,
  const Velo_HitBase& h0,
  int& first_candidate,
  int& last_candidate
) {
  const float dz = module.z - h0.z;
  const float predx = tx * dz;
  const float predy = ty * dz;
  const float x_prediction = h0.x + predx;
  const float y_prediction = h0.y + predy;
  const float track_extrapolation_phi = hit_phi_even(x_prediction, y_prediction);
  last_candidate = -1;

  first_candidate = binary_search_first_candidate(
    hit_Phis + module.hitStart,
    module.hitNums,
    track_extrapolation_phi,
    Velo_Tracking_forward_phi_tolerance
  );

  if (first_candidate != -1) {
    // Find last candidate
    last_candidate = binary_search_second_candidate(
      hit_Phis + module.hitStart + first_candidate,
      module.hitNums - first_candidate,
      track_extrapolation_phi,
      Velo_Tracking_forward_phi_tolerance
    );
    first_candidate += module.hitStart;
    last_candidate = last_candidate==0 ? first_candidate+1 : first_candidate+last_candidate;
  }
}

void find_forward_candidates_odd(
  uniform const Velo_Module& module,
  const float tx,
  const float ty,
  const float* hit_Phis,
  const Velo_HitBase& h0,
  int& first_candidate,
  int& last_candidate
) {
  const float dz = module.z - h0.z;
  const float predx = tx * dz;
  const float predy = ty * dz;
  const float x_prediction = h0.x + predx;
  const float y_prediction = h0.y + predy;
  const float track_extrapolation_phi = hit_phi_odd(x_prediction, y_prediction);
  last_candidate = -1;

  first_candidate = binary_search_first_candidate(
    hit_Phis + module.hitStart,
    module.hitNums,
    track_extrapolation_phi,
    Velo_Tracking_forward_phi_tolerance
  );

  if (first_candidate != -1) {
    // Find last candidate
    last_candidate = binary_search_second_candidate(
      hit_Phis + module.hitStart + first_candidate,
      module.hitNums - first_candidate,
      track_extrapolation_phi,
      Velo_Tracking_forward_phi_tolerance
    );
    first_candidate += module.hitStart;
    last_candidate = last_candidate==0 ? first_candidate+1 : first_candidate+last_candidate;
  }
}

/**
 * @brief Fits hits to tracks.
 *
 * @details In case the tolerances constraints are met,
 *          returns the chi2 weight of the track. Otherwise,
 *          returns FLT_MAX.
 */
float fit_hit_to_track(
  const Velo_HitBase& h0,
  const Velo_HitBase& h2,
  const float predx,
  const float predy,
  const float scatterDenom2
) {
  // tolerances
  const float x_prediction = h0.x + predx;
  const float dx = abs(x_prediction - h2.x);
  const bool tolx_condition = dx < Velo_Tracking_tolerance;

  const float y_prediction = h0.y + predy;
  const float dy = abs(y_prediction - h2.y);
  const bool toly_condition = dy < Velo_Tracking_tolerance;

  // Scatter
  const float scatterNum = (dx * dx) + (dy * dy);
  const float scatter = scatterNum * scatterDenom2;

  const bool scatter_condition = scatter < Velo_Tracking_max_scatter_forwarding;
  const bool condition = tolx_condition && toly_condition && scatter_condition;

  return condition ? scatter : FLT_MAX;
}

/**
 * @brief Performs the track forwarding of forming tracks
 */
void track_forwarding(
  uniform const float* hit_Xs,
  uniform const float* hit_Ys,
  uniform const float* hit_Zs,
  uniform const float* hit_Phis,
  uniform int8* hit_used,
  uniform unsigned int32* tracks_insertPointer,
  uniform unsigned int32* ttf_insertPointer,
  uniform unsigned int32* weaktracks_insertPointer,
  uniform const Velo_Module* uniform module_data,
  uniform const unsigned int32 diff_ttf,
  uniform unsigned int32* tracks_to_follow,
  uniform Velo_TrackletHits* weak_tracks,
  uniform const unsigned int32 prev_ttf,
  uniform Velo_TrackletHits* tracklets,
  uniform Velo_TrackHits* tracks,
  uniform const unsigned int32 number_of_hits
) {
  // Assign a track to follow to each thread
  foreach (ttf_element = 0 ... diff_ttf) {
    const unsigned int32 fulltrackno = tracks_to_follow[(prev_ttf + ttf_element) % Velo_Tracking_ttf_modulo];
    const bool track_flag = (fulltrackno & 0x80000000) == 0x80000000;
    const int8 skipped_modules = (fulltrackno & 0x70000000) >> 28;
    unsigned int32 trackno = fulltrackno & 0x0FFFFFFF;
    // assert(track_flag ? trackno < Velo_Tracking_ttf_modulo : trackno < Velo_Constants_max_tracks);

    Velo_TrackHits t = track_flag ? Velo_TrackHits_ctor(tracklets, trackno) : tracks[trackno];

    // Load last two hits in h0, h1
    // assert(t.hitsNum < Velo_Constants_max_track_size);
    const unsigned int32 h0_num = t.hits[t.hitsNum - 2];
    const unsigned int32 h1_num = t.hits[t.hitsNum - 1];

    // assert(h0_num < number_of_hits);
    const Velo_HitBase h0 = Velo_HitBase_ctor(hit_Xs[h0_num], hit_Ys[h0_num], hit_Zs[h0_num]);

    // assert(h1_num < number_of_hits);
    const Velo_HitBase h1 = Velo_HitBase_ctor(hit_Xs[h1_num], hit_Ys[h1_num], hit_Zs[h1_num]);

    // Track forwarding over t, for all hits in the next module
    // Line calculations
    const float td = 1.0f / (h1.z - h0.z);
    const float txn = (h1.x - h0.x);
    const float tyn = (h1.y - h0.y);
    const float tx = txn * td;
    const float ty = tyn * td;

    // Find the best candidate
    float best_fit = FLT_MAX;
    unsigned int16 best_h2;

    // Get candidates by performing a binary search in expected phi
    int odd_first_candidate, odd_last_candidate;
    find_forward_candidates_odd(
      module_data[4],
      tx,
      ty,
      hit_Phis,
      h0,
      odd_first_candidate,
      odd_last_candidate
    );

    int even_first_candidate, even_last_candidate;
    find_forward_candidates_even(
      module_data[5],
      tx,
      ty,
      hit_Phis,
      h0,
      even_first_candidate,
      even_last_candidate
    );

    // Search on both modules in the same for loop
    const int total_odd_candidates = odd_last_candidate - odd_first_candidate;
    const int total_even_candidates = even_last_candidate - even_first_candidate;
    const int total_candidates = total_odd_candidates + total_even_candidates;

    for (int j=0; j<total_candidates; ++j) {
      const int h2_index = j < total_odd_candidates ?
        odd_first_candidate + j :
        even_first_candidate + j - total_odd_candidates;

      const Velo_HitBase h2 = Velo_HitBase_ctor(hit_Xs[h2_index], hit_Ys[h2_index], hit_Zs[h2_index]);

      const float dz = h2.z - h0.z;
      const float predx = tx * dz;
      const float predy = ty * dz;
      const float scatterDenom2 = 1.f / ((h2.z - h1.z) * (h2.z - h1.z));

      const float fit = fit_hit_to_track(
        h0,
        h2,
        predx,
        predy,
        scatterDenom2
      );

      // We keep the best one found
      if (fit < best_fit) {
        best_fit = fit;
        best_h2 = h2_index;
      }
    }

    // Condition for finding a h2
    if (best_fit != FLT_MAX) {
      // Mark h2 as used
      // assert(best_h2 < number_of_hits);
      hit_used[best_h2] = 1;

      // Update the tracks to follow, we'll have to follow up
      // this track on the next iteration :)
      // assert(t.hitsNum < Velo_Constants_max_track_size);
      t.hits[t.hitsNum++] = best_h2;

      // Update the track in the bag
      if (t.hitsNum <= 4) {
        // assert(t.hits[0] < number_of_hits);
        // assert(t.hits[1] < number_of_hits);
        // assert(t.hits[2] < number_of_hits);

        // Also mark the first three as used
        hit_used[t.hits[0]] = 1;
        hit_used[t.hits[1]] = 1;
        hit_used[t.hits[2]] = 1;

        // If it is a track made out of less than or equal than 4 hits,
        // we have to allocate it in the tracks pointer
        trackno = atomic_add_global(tracks_insertPointer, 1);
      }

      // Copy the track into tracks
      // assert(trackno < Velo_Constants_max_tracks);
      tracks[trackno] = t;

      // Add the tracks to the bag of tracks to_follow
      foreach_active(active_i) {
        const unsigned int32 ttfP = ttf_insertPointer[0] % Velo_Tracking_ttf_modulo;
        ttf_insertPointer[0] += 1;
        tracks_to_follow[ttfP] = trackno;
      }
    }
    // A track just skipped a module
    // We keep it for another round
    else if (skipped_modules < Velo_Tracking_max_skipped_modules) {
      // Form the new mask
      trackno = ((skipped_modules + 1) << 28) | (fulltrackno & 0x8FFFFFFF);

      // Add the tracks to the bag of tracks to_follow
      foreach_active(active_i) {
        const unsigned int32 ttfP = ttf_insertPointer[0] % Velo_Tracking_ttf_modulo;
        ttf_insertPointer[0] += 1;
        tracks_to_follow[ttfP] = trackno;
      }
    }
    // If there are only three hits in this track,
    // mark it as "doubtful"
    else if (t.hitsNum == 3) {
      const unsigned int32 weakP = atomic_add_global(weaktracks_insertPointer, 1) % Velo_Tracking_ttf_modulo;
      // assert(weakP < Velo_Tracking_max_weak_tracks);
      weak_tracks[weakP] = Velo_TrackletHits_ctor(t.hits[0], t.hits[1], t.hits[2]);
    }
    // In the "else" case, we couldn't follow up the track,
    // so we won't be track following it anymore.
  }
}
