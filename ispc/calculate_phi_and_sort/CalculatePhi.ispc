#include "common/VeloCommon.ih"
#include "utils/HitPhi.ih"

/**
 * @brief Calculates a phi even side
 */
void calculate_phi_side_even(
  uniform const unsigned int* uniform module_hitStarts,
  uniform const unsigned int* uniform module_hitNums,
  uniform const float* hit_Xs,
  uniform const float* hit_Ys,
  uniform float* hit_Phis,
  uniform const unsigned int starting_module
) {
  for (uniform unsigned int module=starting_module; module<Velo_Constants_n_modules; module += 2) {
    uniform const unsigned int hit_start = module_hitStarts[module];
    uniform const unsigned int hit_num = module_hitNums[module];

    // Calculate phis
    foreach (hit_rel_id = 0 ... hit_num) {
      const unsigned int hit_index = hit_start + hit_rel_id;
      hit_Phis[hit_index] = hit_phi_even(hit_Xs[hit_index], hit_Ys[hit_index]);
    }
  }
}

void calculate_phi_side_odd(
  uniform const unsigned int* uniform module_hitStarts,
  uniform const unsigned int* uniform module_hitNums,
  uniform const float* hit_Xs,
  uniform const float* hit_Ys,
  uniform float* hit_Phis,
  uniform const unsigned int starting_module
) {
  for (uniform unsigned int module=starting_module; module<Velo_Constants_n_modules; module += 2) {
    uniform const unsigned int hit_start = module_hitStarts[module];
    uniform const unsigned int hit_num = module_hitNums[module];

    // Calculate phis
    foreach (hit_rel_id = 0 ... hit_num) {
      const unsigned int hit_index = hit_start + hit_rel_id;
      hit_Phis[hit_index] = hit_phi_odd(hit_Xs[hit_index], hit_Ys[hit_index]);
    }
  }
}

/**
 * @brief Calculates phi for each hit
 */
void calculate_phi(
  uniform const unsigned int* uniform module_hitStarts,
  uniform const unsigned int* uniform module_hitNums,
  uniform const float* hit_Xs,
  uniform const float* hit_Ys,
  uniform float* hit_Phis
) {
  // Odd modules
  calculate_phi_side_odd(
    module_hitStarts,
    module_hitNums,
    hit_Xs,
    hit_Ys,
    hit_Phis,
    1
  );

  // Even modules
  calculate_phi_side_even(
    module_hitStarts,
    module_hitNums,
    hit_Xs,
    hit_Ys,
    hit_Phis,
    0
  );
}
