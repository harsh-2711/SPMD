#include "CalculatePhi.ispc"
#include "SortByPhi.ispc"

/**
 * @brief Track forwarding algorithm based on triplet finding
 */
export void calculate_phi_and_sort(
  uniform unsigned int32 dev_module_cluster_start [],
  uniform unsigned int32 dev_module_cluster_num [],
  uniform float dev_velo_cluster_x [],
  uniform float dev_velo_cluster_y [],
  uniform float dev_velo_cluster_z [],
  uniform unsigned int32 dev_velo_cluster_id [],
  uniform float dev_velo_cluster_phi [],
  uniform unsigned int32 dev_velo_cluster_temp [],
  uniform const unsigned int32 event_number,
  uniform const unsigned int32 number_of_events
) {
  // Pointers to data within the event
  uniform const unsigned int32 number_of_hits = dev_module_cluster_start[Velo_Constants_n_modules * number_of_events];
  uniform const unsigned int32* uniform module_hitStarts = dev_module_cluster_start + event_number * Velo_Constants_n_modules;
  uniform const unsigned int32* uniform module_hitNums = dev_module_cluster_num + event_number * Velo_Constants_n_modules;
  
  uniform float* hit_Xs = dev_velo_cluster_x;
  uniform float* hit_Ys = dev_velo_cluster_y;
  uniform float* hit_Zs = dev_velo_cluster_z;
  uniform unsigned int32* hit_IDs = dev_velo_cluster_id;
  uniform float* hit_Phis = dev_velo_cluster_phi;
  uniform unsigned int32* hit_temp = dev_velo_cluster_temp;

  // TODO: Check speed of various options
  // Initialize hit_permutations to zero
  // uniform const unsigned int32 event_hit_start = module_hitStarts[0];
  // uniform const unsigned int32 event_number_of_hits = module_hitStarts[Velo_Constants_n_modules] - event_hit_start;

  // // Sort by phi
  // sort_by_phi(
  //   module_hitStarts,
  //   module_hitNums,
  //   hit_Xs,
  //   hit_Ys,
  //   hit_Zs,
  //   hit_IDs,
  //   hit_temp,
  //   hit_permutations
  // );

  // memory_barrier();

  // Calculate phi and populate hit_permutations
  calculate_phi(
    module_hitStarts,
    module_hitNums,
    (float*) hit_temp,
    hit_Xs,
    hit_Phis
  );
}
