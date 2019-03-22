#include "common/VeloCommon.ih"
#include "utils/ApplyPermutation.ispc"

/**
 * @brief Calculates phi for each hit
 */
void sort_by_phi(
  uniform const unsigned int* uniform module_hitStarts,
  uniform const unsigned int* uniform module_hitNums,
  float* hit_Xs,
  float* hit_Ys,
  float* hit_Zs,
  unsigned int32* hit_IDs,
  unsigned int32* hit_temp,
  unsigned int8* hit_permutations
) {
  // Let's work with new pointers
  // Note: It is important we populate later on in strictly
  //       the same order, to not lose data
  float* new_hit_Xs = (float*) hit_temp;
  float* new_hit_Ys = hit_Xs;
  float* new_hit_Zs = hit_Ys;
  unsigned int32* new_hit_IDs = (unsigned int32*) hit_Zs;

  // Apply permutation across all arrays
  apply_permutation(module_hitStarts, module_hitNums, hit_permutations, hit_Xs, new_hit_Xs);
  memory_barrier();
  apply_permutation(module_hitStarts, module_hitNums, hit_permutations, hit_Ys, new_hit_Ys);
  memory_barrier();
  apply_permutation(module_hitStarts, module_hitNums, hit_permutations, hit_Zs, new_hit_Zs);
  memory_barrier();
  apply_permutation(module_hitStarts, module_hitNums, hit_permutations, hit_IDs, new_hit_IDs);
}
