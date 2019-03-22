#pragma once

#include "VeloDefinitions.h"
#include "VeloEventModel.h"
#include "Logger.h"

void clustering(
  const aligned_vector<uint8_t>& sp_patterns,
  const aligned_vector<uint8_t>& sp_sizes,
  const aligned_vector<float>& sp_fx,
  const aligned_vector<float>& sp_fy,
  const VeloGeometry& geometry,
  const aligned_vector<char>& dev_velo_raw_input,
  const aligned_vector<uint32_t>& dev_velo_raw_input_offsets,
  aligned_vector<uint32_t>& dev_estimated_input_size,
  aligned_vector<uint32_t>& dev_module_cluster_num,
  aligned_vector<float>& dev_velo_cluster_x,
  aligned_vector<float>& dev_velo_cluster_y,
  aligned_vector<float>& dev_velo_cluster_z,
  aligned_vector<uint32_t>& dev_velo_cluster_id,
  aligned_vector<float>& dev_velo_cluster_phi,
  aligned_vector<uint32_t>& dev_velo_cluster_temp,
  const aligned_vector<uint32_t>& dev_event_list,
  const uint32_t number_of_events);
