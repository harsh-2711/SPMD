#include "common/VeloCommon.ih"

/**
 * @brief Search for compatible triplets in
 *        three neighbouring modules on one side
 */
void track_seeding(
  uniform const float* hit_Xs,
  uniform const float* hit_Ys,
  uniform const float* hit_Zs,
  uniform const Velo_Module* uniform module_data,
  uniform const int16* h0_candidates,
  uniform const int16* h2_candidates,
  uniform int8* hit_used,
  uniform unsigned int32* tracklets_insertPointer,
  uniform unsigned int32* uniform ttf_insertPointer,
  uniform Velo_TrackletHits* tracklets,
  uniform unsigned int32* tracks_to_follow,
  uniform unsigned int16* h1_indices,
  uniform unsigned int32* uniform local_number_of_hits
) {
  // Add to an array all non-used h1 hits with candidates
  foreach (h1_rel_index = 0 ... module_data[2].hitNums) {
    const unsigned int32 h1_index = module_data[2].hitStart + h1_rel_index;
    const int16 h0_first_candidate = h0_candidates[2*h1_index];
    const int16 h2_first_candidate = h2_candidates[2*h1_index];

    // print("%i, %i, %i, %i\n", h1_index, h0_first_candidate, h2_first_candidate, hit_used[h1_index]);
    if (hit_used[h1_index] == 0 && h0_first_candidate!=-1 && h2_first_candidate!=-1) {
      foreach_active(active_i) {
        uniform const unsigned int32 current_hit = *local_number_of_hits;
        h1_indices[current_hit] = h1_index;
        ++(*local_number_of_hits);
      }
    }
  }

  // Also add other side
  foreach (h1_rel_index = 0 ... module_data[3].hitNums) {
    const unsigned int32 h1_index = module_data[3].hitStart + h1_rel_index;
    const int16 h0_first_candidate = h0_candidates[2*h1_index];
    const int16 h2_first_candidate = h2_candidates[2*h1_index];
    if (hit_used[h1_index] == 0 && h0_first_candidate!=-1 && h2_first_candidate!=-1) {
      foreach_active(active_i) {
        uniform const unsigned int32 current_hit = *local_number_of_hits;
        h1_indices[current_hit] = h1_index;
        ++(*local_number_of_hits);
      }
    }
  }

  // Due to h1_indices
  memory_barrier();

  // print("h1 size: %i\n", local_number_of_hits[0]);

  // print("h1 indices:\n");
  // print(" number of candidates: %i\n", local_number_of_hits[0]);
  // for (int i=0; i<local_number_of_hits[0]; ++i) {
  //   print("%i, ", h1_indices[i]);
  // }
  // print("\n");

  uniform const unsigned int32 number_of_hits_h1 = local_number_of_hits[0];
  foreach (h1_rel_index = 0 ... number_of_hits_h1) {
    int16 best_h0 = 0;
    int16 best_h2 = 0;
    float best_fit = FLT_MAX;

    // Fetch h1
    // const auto h1_rel_index = h1_indices[h1_rel_index];
    const unsigned int32 h1_index = h1_indices[h1_rel_index];
    const Velo_HitBase h1 = Velo_HitBase_ctor(hit_Xs[h1_index], hit_Ys[h1_index], hit_Zs[h1_index]);

    // Iterate over all h0, h2 combinations
    // Ignore used hits
    const int16 h0_first_candidate = h0_candidates[2*h1_index];
    const int16 h0_last_candidate = h0_candidates[2*h1_index + 1];
    const int16 h2_first_candidate = h2_candidates[2*h1_index];
    const int16 h2_last_candidate = h2_candidates[2*h1_index + 1];

    for (int16 h0_index=h0_first_candidate; h0_index<h0_last_candidate; ++h0_index) {
      if (hit_used[h0_index] == 0) {
        // Fetch h0
        const Velo_HitBase h0 = Velo_HitBase_ctor(hit_Xs[h0_index], hit_Ys[h0_index], hit_Zs[h0_index]);

        // Finally, iterate over all h2 indices
        for (int16 h2_index=h2_first_candidate; h2_index<h2_last_candidate; ++h2_index) {
          if (hit_used[h2_index] == 0) {
            // const auto best_fits_index = thread_id_y*Velo_Tracking_max_numhits_in_module + h1_rel_index;

            // Our triplet is h0_index, h1_index, h2_index
            // Fit it and check if it's better than what this thread had
            // for any triplet with h1
            const Velo_HitBase h2 = Velo_HitBase_ctor(hit_Xs[h2_index], hit_Ys[h2_index], hit_Zs[h2_index]);

            const float dmax = Velo_Tracking_max_slope * (h0.z - h1.z);
            const float scatterDenom2 = 1.f / ((h2.z - h1.z) * (h2.z - h1.z));
            const float z2_tz = (h2.z - h0.z) / (h1.z - h0.z);

            // Calculate prediction
            const float x = h0.x + (h1.x - h0.x) * z2_tz;
            const float y = h0.y + (h1.y - h0.y) * z2_tz;
            const float dx = x - h2.x;
            const float dy = y - h2.y;

            // Calculate fit
            const float scatterNum = (dx * dx) + (dy * dy);
            const float scatter = scatterNum * scatterDenom2;
            const bool condition = abs(h1.x - h0.x) < dmax &&
                                   abs(h1.y - h0.y) < dmax &&
                                   abs(dx) < Velo_Tracking_tolerance &&
                                   abs(dy) < Velo_Tracking_tolerance &&
                                   scatter < Velo_Tracking_max_scatter_seeding &&
                                   scatter < best_fit;

            if (condition) {
              // print("%i, %f, %i, %f, %f\n", programIndex, scatter * 1000000000, scatter>0.f, h0_index, h2_index);

              // Populate fit, h0 and h2 in case we have found a better one
              best_fit = scatter;
              best_h0 = h0_index;
              best_h2 = h2_index;
            }
          }
        }
      }
    }

    // If this condition holds, then necessarily best_fit < FLT_MAX
    if (best_fit < FLT_MAX) {
      foreach_active(active_i) {
        // Add the track to the bag of tracks
        const unsigned int32 trackP = tracklets_insertPointer[0] % Velo_Tracking_ttf_modulo;
        tracklets_insertPointer[0] += 1;
        tracklets[trackP] = Velo_TrackletHits_ctor(best_h0, h1_index, best_h2);

        // Add the tracks to the bag of tracks to_follow
        // Note: The first bit flag marks this is a tracklet (hitsNum == 3),
        // and hence it is stored in tracklets
        const unsigned int32 ttfP = ttf_insertPointer[0] % Velo_Tracking_ttf_modulo;
        ttf_insertPointer[0] += 1;
        tracks_to_follow[ttfP] = 0x80000000 | trackP;
      }
    }
  }
}
