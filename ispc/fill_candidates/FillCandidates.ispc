#include "common/VeloCommon.ih"
#include "utils/BinarySearchFirstCandidate.ih"

void fill_candidates_impl(
  uniform int16* h0_candidates,
  uniform int16* h2_candidates,
  uniform const unsigned int32* uniform module_hitStarts,
  uniform const unsigned int32* uniform module_hitNums,
  uniform const float* hit_Phis,
  uniform const unsigned int32 hit_offset
) {
  // Notation is m0, m1, m2 in reverse order for each module
  // A hit in those is h0, h1, h2 respectively

  // Assign a h1 to each threadIdx.x
  for (uniform int module_index = 2; module_index < 50; ++module_index) {
    uniform const unsigned int32 m1_hitNums = module_hitNums[module_index];

    foreach (h1_rel_index = 0 ... m1_hitNums) {
      // Find for module module_index, hit h1_rel_index the candidates
      const unsigned int32 m0_hitStarts = module_hitStarts[module_index+2] - hit_offset;
      const unsigned int32 m2_hitStarts = module_hitStarts[module_index-2] - hit_offset;
      const unsigned int32 m0_hitNums = module_hitNums[module_index+2];
      const unsigned int32 m2_hitNums = module_hitNums[module_index-2];

      const unsigned int32 h1_index = module_hitStarts[module_index] + h1_rel_index - hit_offset;

      // Calculate phi limits
      const float h1_phi = hit_Phis[h1_index];

      int first_h0_bin = -1, last_h0_bin = -1;
      if (m0_hitNums > 0) {
        // Do a binary search for h0 candidates
        first_h0_bin = binary_search_first_candidate(
          hit_Phis + m0_hitStarts,
          m0_hitNums,
          h1_phi,
          Velo_Tracking_phi_extrapolation
        );

        if (first_h0_bin != -1) {
          // Find last h0 candidate
          last_h0_bin = binary_search_second_candidate(
            hit_Phis + m0_hitStarts + first_h0_bin,
            m0_hitNums - first_h0_bin,
            h1_phi,
            Velo_Tracking_phi_extrapolation
          );
          first_h0_bin += m0_hitStarts;
          last_h0_bin = last_h0_bin==0 ? first_h0_bin+1 : first_h0_bin+last_h0_bin;
        }
      }

      h0_candidates[2*h1_index] = first_h0_bin;
      h0_candidates[2*h1_index + 1] = last_h0_bin;

      int first_h2_bin = -1, last_h2_bin = -1;
      if (m2_hitNums > 0) {
        // Do a binary search for h2 candidates
        first_h2_bin = binary_search_first_candidate(
          hit_Phis + m2_hitStarts,
          m2_hitNums,
          h1_phi,
          Velo_Tracking_phi_extrapolation
        );

        if (first_h2_bin != -1) {
          // Find last h0 candidate
          last_h2_bin = binary_search_second_candidate(
            hit_Phis + m2_hitStarts + first_h2_bin,
            m2_hitNums - first_h2_bin,
            h1_phi,
            Velo_Tracking_phi_extrapolation
          );
          first_h2_bin += m2_hitStarts;
          last_h2_bin = last_h2_bin==0 ? first_h2_bin+1 : first_h2_bin+last_h2_bin;
        }
      }

      h2_candidates[2*h1_index] = first_h2_bin;
      h2_candidates[2*h1_index + 1] = last_h2_bin;
    }
  }
}

export void fill_candidates(
  uniform float dev_velo_cluster_x [],
  uniform float dev_velo_cluster_y [],
  uniform float dev_velo_cluster_z [],
  uniform unsigned int32 dev_velo_cluster_id [],
  uniform float dev_velo_cluster_phi [],
  uniform unsigned int32 dev_velo_cluster_temp [],
  uniform unsigned int32 dev_module_cluster_start [],
  uniform unsigned int32 dev_module_cluster_num [],
  uniform int16 dev_h0_candidates [],
  uniform int16 dev_h2_candidates [],
  uniform const unsigned int32 event_number,
  uniform const unsigned int32 number_of_events)
{
  // Pointers to data within the event
  uniform const unsigned int32 number_of_hits = dev_module_cluster_start[Velo_Constants_n_modules * number_of_events];
  uniform const unsigned int32* uniform module_hitStarts = dev_module_cluster_start + event_number * Velo_Constants_n_modules;
  uniform const unsigned int32* uniform module_hitNums = dev_module_cluster_num + event_number * Velo_Constants_n_modules;
  uniform const unsigned int32 hit_offset = module_hitStarts[0];
  // assert((module_hitStarts[52] - module_hitStarts[0]) < Velo::Constants::max_number_of_hits_per_event);

  // Order has changed since SortByPhi
  uniform const float* hit_Phis = (float*) (dev_velo_cluster_phi + hit_offset);
  uniform int16* h0_candidates = dev_h0_candidates + 2*hit_offset;
  uniform int16* h2_candidates = dev_h2_candidates + 2*hit_offset;

  fill_candidates_impl(
    h0_candidates,
    h2_candidates,
    module_hitStarts,
    module_hitNums,
    hit_Phis,
    hit_offset
  );
}
