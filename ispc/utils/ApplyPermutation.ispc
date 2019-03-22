#include "common/VeloConstants.ih"
#include "ApplyPermutation.ih"

void apply_permutation(
  uniform const unsigned int* uniform module_hitStarts,
  uniform const unsigned int* uniform module_hitNums,
  unsigned int8* permutation,
  unsigned int32* prev_container,
  unsigned int32* new_container)
{
  // Apply permutation across all hits
  for (uniform unsigned int module=0; module<Velo_Constants_n_modules; module += 1) {
    uniform const unsigned int hit_start = module_hitStarts[module];
    uniform const unsigned int hit_num = module_hitNums[module];

    foreach (i = 0 ... hit_num) {
      const unsigned int8 hit_index_local = permutation[hit_start + i];
      new_container[hit_start + i] = prev_container[hit_start + hit_index_local];
    }
  }
}

void apply_permutation(
  uniform const unsigned int* uniform module_hitStarts,
  uniform const unsigned int* uniform module_hitNums,
  unsigned int8* permutation,
  float* prev_container,
  float* new_container)
{
  // Apply permutation across all hits
  for (uniform unsigned int module=0; module<Velo_Constants_n_modules; module += 1) {
    uniform const unsigned int hit_start = module_hitStarts[module];
    uniform const unsigned int hit_num = module_hitNums[module];

    foreach (i = 0 ... hit_num) {
      const int hit_index_local = permutation[hit_start + i];
      new_container[hit_start + i] = prev_container[hit_start + hit_index_local];
    }
  }
}
