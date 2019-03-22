#pragma once

#include "AlignedAllocator.h"
#include <cstdint>

static constexpr uint maxSciFiUTClusters = 9750;

void global_event_cut(
  aligned_vector<char> ut_raw_input,
  aligned_vector<uint32_t> ut_raw_input_offsets,
  aligned_vector<char> scifi_raw_input,
  aligned_vector<uint32_t> scifi_raw_input_offsets,
  aligned_vector<uint32_t>& selected_event_list,
  uint number_of_events);
