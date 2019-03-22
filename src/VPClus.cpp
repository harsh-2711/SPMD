#include "VPClus.h"
#include "ClusteringDefinitions.h"
#include <array>
#include <algorithm>
#include <math.h>

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
  const uint32_t number_of_events)
{
  std::array<unsigned char, VP::NPixelsPerSensor> buffer {};
  std::array<uint32_t, 1000> stack;
  uint32_t stack_size = 0;
  std::array<uint32_t, 1000> pixel_idx;
  uint32_t pixel_idx_size = 0;

  const auto array_push_back = [] (
    std::array<uint32_t, 1000>& array,
    uint32_t& array_size,
    uint32_t idx)
  {
    array[array_size] = idx;
    array_size++;
  };

  const auto array_pop_back = [] (
    std::array<uint32_t, 1000>& array,
    uint32_t& array_size)
  {
    const auto idx = array[array_size-1];
    array_size--;
    return idx;
  };

  const auto stack_push_back = [&stack, &stack_size, &array_push_back] (uint32_t idx) {
    return array_push_back(stack, stack_size, idx);
  };

  const auto stack_pop_back = [&stack, &stack_size, &array_pop_back] () {
    return array_pop_back(stack, stack_size);
  };

  std::array<uint8_t, 256> permutation;

  // "Closures" for odd and even module comparison
  auto cmp_phi_for_odd_modules = [] (float* x, float* y) {
    // sorting in phi for even modules
    return [&x, &y] (const uint8_t a, const uint8_t b) {
      return (y[a] < 0.f && y[b] > 0.f) ||
             // same y side even and odd modules, check y1/x1 < y2/x2
             ((y[a]* y[b]) > 0.f && (y[a]*x[b] < y[b]*x[a]));
    };
  };

  auto cmp_phi_for_even_modules = [] (float* x, float* y) {
    // sorting in phi for odd modules
    return [&x, &y] (const uint8_t a, const uint8_t b) {
      return (y[a] > 0.f  && y[b] < 0.f) ||
             // same y side even and odd modules, check y1/x1 < y2/x2
             ((y[a]* y[b]) > 0.f && (y[a]*x[b] < y[b]*x[a]));
    };
  };

  auto sort_module = [] (std::array<uint8_t, 256>& dev_hit_permutation,
    const uint32_t current_size, const auto& cmp) {
    std::sort(dev_hit_permutation.begin(),
      dev_hit_permutation.begin() + current_size,
      cmp);
  };

  // Start offsets
  dev_estimated_input_size[0] = 0;

  for (size_t i=0; i<number_of_events; ++i) {
    const uint event_number = dev_event_list[i];
    
    VeloRawEvent e (dev_velo_raw_input.data() + dev_velo_raw_input_offsets[event_number]);

    auto total_sp_count = 0;

    int previous_module_number = 0;
    int current_module_number = 0;
    for (unsigned int raw_bank=0; raw_bank<e.number_of_raw_banks; ++raw_bank) {
      // std::vector<uint32_t> pixel_idx;
      pixel_idx_size = 0;

      const auto velo_raw_bank = VeloRawBank(e.payload + e.raw_bank_offset[raw_bank]);
      
      const unsigned int sensor = velo_raw_bank.sensor_index;
      const unsigned int module_number = sensor / geometry.number_of_sensors_per_module;
      const float* ltg = geometry.ltg + 16 * sensor;
      current_module_number = module_number;

      if (previous_module_number < current_module_number) {
        // Store permutation of clusters we just calculated
        // Calculate offset (prefix sum)
        const uint32_t offset = dev_estimated_input_size[i * Velo::Constants::n_modules + previous_module_number];
        const uint32_t size = dev_module_cluster_num[i * Velo::Constants::n_modules + previous_module_number];
        dev_estimated_input_size[i * Velo::Constants::n_modules + previous_module_number + 1] = 
          offset + size;

        // We need to grow the temp container by size elements
        dev_velo_cluster_temp.resize(dev_velo_cluster_temp.size() + size);
        
        float* x_with_offset = ((float*) dev_velo_cluster_x.data()) + offset;
        float* y_with_offset = ((float*) dev_velo_cluster_y.data()) + offset;
        float* z_with_offset = ((float*) dev_velo_cluster_z.data()) + offset;
        uint32_t* id_with_offset = ((uint32_t*) dev_velo_cluster_id.data()) + offset;
        uint32_t* temp_with_offset = ((uint32_t*) dev_velo_cluster_temp.data()) + offset;

        for (uint8_t j=0; j<size; ++j) {
          permutation[j] = j;
        }

        if ((previous_module_number % 2) == 1) {
          sort_module(permutation, size,
            cmp_phi_for_odd_modules(x_with_offset, y_with_offset));
        } else {
          sort_module(permutation, size,
            cmp_phi_for_even_modules(x_with_offset, y_with_offset));
        }

        float* new_hit_Xs = (float*) temp_with_offset;
        float* new_hit_Ys = x_with_offset;
        float* new_hit_Zs = y_with_offset;
        uint32_t* new_hit_IDs = (uint32_t*) z_with_offset;

        const auto new_sort = [&size] (auto* a, auto* b, const uint8_t* permutation) {
          for (int i=0; i<size; ++i) {
            const auto perm = permutation[i];
            b[i] = a[perm];
          }
        };

        const auto permutation_p = reinterpret_cast<const uint8_t*>(permutation.data());
        new_sort(x_with_offset, new_hit_Xs, permutation_p);
        new_sort(y_with_offset, new_hit_Ys, permutation_p);
        new_sort(z_with_offset, new_hit_Zs, permutation_p);
        new_sort(id_with_offset, new_hit_IDs, permutation_p);

        previous_module_number = current_module_number;
      }

      total_sp_count += velo_raw_bank.sp_count;

      // info_cout << "Event " << event_number << ", module " << module_number << std::endl;

      for (unsigned int j=0; j<velo_raw_bank.sp_count; ++j) {
        const uint32_t sp_word = *(velo_raw_bank.sp_word + j);

        uint8_t sp = sp_word & 0xFFU;
        
        // protect against zero super pixels.
        if (0 == sp) { continue; };

        const uint32_t sp_addr = (sp_word & 0x007FFF00U) >> 8;
        const uint32_t sp_row = sp_addr & 0x3FU;
        const uint32_t sp_col = (sp_addr >> 6);
        const uint32_t no_sp_neighbours = sp_word & 0x80000000U;

        // if a super pixel is isolated the clustering boils
        // down to a simple pattern look up.
        // don't do this if we run in offline mode where we want to record all
        // contributing channels; in that scenario a few more us are negligible
        // compared to the complication of keeping track of all contributing
        // channel IDs.
        if (no_sp_neighbours) {
          const int sp_size = sp_sizes[sp];
          const uint32_t idx = sp_patterns[sp];
          const uint32_t chip = sp_col / (VP::ChipColumns / 2);

          if (sp_size & 0x0F) {
            // there is always at least one cluster in the super
            // pixel. look up the pattern and add it.
            const uint32_t row = idx & 0x03U;
            const uint32_t col = (idx >> 2) & 1;
            const uint32_t cx = sp_col * 2 + col;
            const uint32_t cy = sp_row * 4 + row;

            unsigned int cid = get_channel_id(sensor, chip, cx % VP::ChipColumns, cy);

            const float fx = sp_fx[sp * 2];
            const float fy = sp_fy[sp * 2];
            const float local_x = geometry.local_x[cx] + fx * geometry.x_pitch[cx];
            const float local_y = (cy + 0.5 + fy) * geometry.pixel_size;

            const float gx = ltg[0] * local_x + ltg[1] * local_y + ltg[9];
            const float gy = ltg[3] * local_x + ltg[4] * local_y + ltg[10];
            const float gz = ltg[6] * local_x + ltg[7] * local_y + ltg[11];

            dev_module_cluster_num[i * Velo::Constants::n_modules + module_number] += 1;
            dev_velo_cluster_x.push_back(gx);
            dev_velo_cluster_y.push_back(gy);
            dev_velo_cluster_z.push_back(gz);
            dev_velo_cluster_id.push_back(cid);
          }

          // if there is a second cluster for this pattern
          // add it as well.
          if (idx & 8) {
            const uint32_t row = (idx >> 4) & 3;
            const uint32_t col = (idx >> 6) & 1;
            const uint32_t cx = sp_col * 2 + col;
            const uint32_t cy = sp_row * 4 + row;

            unsigned int cid = get_channel_id(sensor, chip, cx % VP::ChipColumns, cy);

            const float fx = sp_fx[sp * 2 + 1];
            const float fy = sp_fy[sp * 2 + 1];
            const float local_x = geometry.local_x[cx] + fx * geometry.x_pitch[cx];
            const float local_y = (cy + 0.5 + fy) * geometry.pixel_size;

            const float gx = ltg[0] * local_x + ltg[1] * local_y + ltg[9];
            const float gy = ltg[3] * local_x + ltg[4] * local_y + ltg[10];
            const float gz = ltg[6] * local_x + ltg[7] * local_y + ltg[11];

            dev_module_cluster_num[i * Velo::Constants::n_modules + module_number] += 1;
            dev_velo_cluster_x.push_back(gx);
            dev_velo_cluster_y.push_back(gy);
            dev_velo_cluster_z.push_back(gz);
            dev_velo_cluster_id.push_back(cid);
          }

          continue;  // move on to next super pixel
        }

        // this one is not isolated or we are targeting clusters; record all
        // pixels.
        for (uint32_t shift = 0; shift < 8; ++shift) {
          const uint8_t pixel = sp & 1;
          if (pixel) {
            const uint32_t row = sp_row * 4 + shift % 4;
            const uint32_t col = sp_col * 2 + shift / 4;
            const uint32_t idx = (col << 8) | row;
            buffer[idx] = pixel;
            // pixel_idx.push_back(idx);
            array_push_back(pixel_idx, pixel_idx_size, idx);
          }
          sp = sp >> 1;
          if (0 == sp) break;
        }
      }

      // the sensor buffer is filled, perform the clustering on
      // clusters that span several super pixels.
      // const unsigned int nidx = pixel_idx.size();
      const unsigned int nidx = pixel_idx_size;
      for (unsigned int irc = 0; irc < nidx; ++irc) {

        const uint32_t idx = pixel_idx[irc];
        const uint8_t pixel = buffer[idx];

        if (0 == pixel) continue;  // pixel is used in another cluster

        // 8-way row scan optimized seeded flood fill from here.
        // std::vector<uint32_t> stack;

        // mark seed as used
        buffer[idx] = 0;

        // initialize sums
        unsigned int x = 0;
        unsigned int y = 0;
        unsigned int n = 0;

        // push seed on stack
        // stack.push_back(idx);
        stack_push_back(idx);

        // as long as the stack is not exhausted:
        // - pop the stack and add popped pixel to cluster
        // - scan the row to left and right, adding set pixels
        //   to the cluster and push set pixels above and below
        //   on the stack (and delete both from the pixel buffer).
        while (stack_size != 0) {

          // pop pixel from stack and add it to cluster
          const uint32_t idx = stack_pop_back();
          const uint32_t row = idx & 0xFFU;
          const uint32_t col = (idx >> 8) & 0x3FFU;
          x += col;
          y += row;
          ++n;

          // check up and down
          uint32_t u_idx = idx + 1;
          if (row < VP::NRows - 1 && buffer[u_idx]) {
            buffer[u_idx] = 0;
            // stack.push_back(u_idx);
            stack_push_back(u_idx);
          }
          uint32_t d_idx = idx - 1;
          if (row > 0 && buffer[d_idx]) {
            buffer[d_idx] = 0;
            // stack.push_back(d_idx);
            stack_push_back(d_idx);
          }

          // scan row to the right
          for (unsigned int c = col + 1; c < VP::NSensorColumns; ++c) {
            const uint32_t nidx = (c << 8) | row;
            // check up and down
            u_idx = nidx + 1;
            if (row < VP::NRows - 1 && buffer[u_idx]) {
              buffer[u_idx] = 0;
              // stack.push_back(u_idx);
              stack_push_back(u_idx);
            }
            d_idx = nidx - 1;
            if (row > 0 && buffer[d_idx]) {
              buffer[d_idx] = 0;
              // stack.push_back(d_idx);
              stack_push_back(d_idx);
            }
            // add set pixel to cluster or stop scanning
            if (buffer[nidx]) {
              buffer[nidx] = 0;
              x += c;
              y += row;
              ++n;
            } else {
              break;
            }
          }

          // scan row to the left
          for (int c = col - 1; c >= 0; --c) {
            const uint32_t nidx = (c << 8) | row;
            // check up and down
            u_idx = nidx + 1;
            if (row < VP::NRows - 1 && buffer[u_idx]) {
              buffer[u_idx] = 0;
              // stack.push_back(u_idx);
              stack_push_back(u_idx);
            }
            d_idx = nidx - 1;
            if (row > 0 && buffer[d_idx]) {
              buffer[d_idx] = 0;
              // stack.push_back(d_idx);
              stack_push_back(d_idx);
            }
            // add set pixel to cluster or stop scanning
            if (buffer[nidx]) {
              buffer[nidx] = 0;
              x += c;
              y += row;
              ++n;
            } else {
              break;
            }
          }
        }  // while the stack is not empty

        // we are done with this cluster, calculate
        // centroid pixel coordinate and fractions.
        const unsigned int cx = x / n;
        const unsigned int cy = y / n;

        // std::cout << "Cluster (cx, cy): " << cx << ", " << cy << std::endl;

        const float fx = x / static_cast<float>(n) - cx;
        const float fy = y / static_cast<float>(n) - cy;

        // store target (3D point for tracking)
        const uint32_t chip = cx / VP::ChipColumns;
        // LHCb::VPChannelID cid(sensor, chip, cx % VP::ChipColumns, cy);
        unsigned int cid = get_channel_id(sensor, chip, cx % VP::ChipColumns, cy);

        const float local_x = geometry.local_x[cx] + fx * geometry.x_pitch[cx];
        const float local_y = (cy + 0.5 + fy) * geometry.pixel_size;
        const float gx = ltg[0] * local_x + ltg[1] * local_y + ltg[9];
        const float gy = ltg[3] * local_x + ltg[4] * local_y + ltg[10];
        const float gz = ltg[6] * local_x + ltg[7] * local_y + ltg[11];

        dev_module_cluster_num[i * Velo::Constants::n_modules + module_number] += 1;
        dev_velo_cluster_x.push_back(gx);
        dev_velo_cluster_y.push_back(gy);
        dev_velo_cluster_z.push_back(gz);
        dev_velo_cluster_id.push_back(cid);
      }
    }

    // Store permutation of clusters we just calculated
    // Calculate offset (prefix sum)
    const uint32_t offset = dev_estimated_input_size[i * Velo::Constants::n_modules + 51];
    const uint32_t size = dev_module_cluster_num[i * Velo::Constants::n_modules + 51];
    dev_estimated_input_size[i * Velo::Constants::n_modules + 51 + 1] = 
      offset + size;
    
    float* x_with_offset = ((float*) dev_velo_cluster_x.data()) + offset;
    float* y_with_offset = ((float*) dev_velo_cluster_y.data()) + offset;

    // We need to grow the temp container by size elements
    dev_velo_cluster_temp.resize(dev_velo_cluster_temp.size() + size);

    for (uint8_t j=0; j<size; ++j) {
      permutation[j] = j;
    }

    sort_module(permutation, size,
      cmp_phi_for_odd_modules(x_with_offset, y_with_offset));

    float* z_with_offset = ((float*) dev_velo_cluster_z.data()) + offset;
    uint32_t* id_with_offset = ((uint32_t*) dev_velo_cluster_id.data()) + offset;
    uint32_t* temp_with_offset = ((uint32_t*) dev_velo_cluster_temp.data()) + offset;

    float* new_hit_Xs = (float*) temp_with_offset;
    float* new_hit_Ys = x_with_offset;
    float* new_hit_Zs = y_with_offset;
    uint32_t* new_hit_IDs = (uint32_t*) z_with_offset;

    const auto new_sort = [&size] (auto* a, auto* b, const uint8_t* permutation) {
      for (int i=0; i<size; ++i) {
        const auto perm = permutation[i];
        b[i] = a[perm];
      }
    };

    const auto permutation_p = reinterpret_cast<const uint8_t*>(permutation.data());
    new_sort(x_with_offset, new_hit_Xs, permutation_p);
    new_sort(y_with_offset, new_hit_Ys, permutation_p);
    new_sort(z_with_offset, new_hit_Zs, permutation_p);
    new_sort(id_with_offset, new_hit_IDs, permutation_p);
  }
}
