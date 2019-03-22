#pragma once

#include <cstdint>
#include "AlignedAllocator.h"

void cache_sp_patterns(
  aligned_vector<unsigned char>& sp_patterns,
  aligned_vector<unsigned char>& sp_sizes,
  aligned_vector<float>& sp_fx,
  aligned_vector<float>& sp_fy
);
