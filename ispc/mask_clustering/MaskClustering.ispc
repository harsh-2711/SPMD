#include "common/VeloCommon.ih"

// Mask for any one pixel array element's next iteration
unsigned int32 current_mask(unsigned int32 p)
{
  return ((p & VeloClustering_mask_top) << 1) | ((p & VeloClustering_mask_bottom) >> 1) |
         ((p & VeloClustering_mask_bottom_right) << 15) | ((p & VeloClustering_mask_top_left) >> 15) | (p >> 16) |
         (p >> 17) | (p << 16) | (p << 17);
}

// Mask from a pixel array element on the left
// to be applied on the pixel array element on the right
unsigned int32 mask_from_left_to_right(unsigned int32 p)
{
  return ((p & VeloClustering_mask_ltr_top_right) >> 15) | (p >> 16) | (p >> 17);
}

// Mask from a pixel array element on the right
// to be applied on the pixel array element on the left
unsigned int32 mask_from_right_to_left(unsigned int32 p)
{
  return ((p & VeloClustering_mask_rtl_bottom_left) << 15) | (p << 16) | (p << 17);
}

// Create mask for found clusters
// o o
// x o
//   o
unsigned int32 cluster_current_mask(unsigned int32 p)
{
  return ((p & VeloClustering_mask_top) << 1) | ((p & VeloClustering_mask_bottom_right) << 15) | (p << 16) | (p << 17);
}

// Require the four pixels of the pattern in order to
// get the candidates
unsigned int32 candidates_current_mask(unsigned int32 p)
{
  return ((p & VeloClustering_mask_bottom) >> 1) & ((p & VeloClustering_mask_top_left) >> 15) & (p >> 16) & (p >> 17);
}

unsigned int32 candidates_current_mask_with_right_clusters(unsigned int32 p, unsigned int32 rp)
{
  return ((p & VeloClustering_mask_bottom) >> 1) & (((p & VeloClustering_mask_top_left) >> 15) | (rp << 17)) &
         ((p >> 16) | (rp << 16)) & ((p >> 17) | ((rp & VeloClustering_mask_rtl_bottom_left) << 15));
}

export void masked_velo_clustering(
  uniform const int8 dev_raw_input [],
  uniform const unsigned int32 dev_raw_input_offsets [],
  uniform unsigned int32 dev_module_cluster_start [],
  uniform unsigned int32 dev_module_cluster_num [],
  uniform unsigned int32 dev_event_candidate_num [],
  uniform unsigned int32 dev_cluster_candidates [],
  uniform unsigned int32 dev_velo_cluster_container [],
  uniform const unsigned int32 dev_event_list [],
  uniform const int8 dev_velo_geometry [],
  uniform unsigned int8 dev_velo_sp_patterns [],
  uniform float dev_velo_sp_fx [],
  uniform float dev_velo_sp_fy [],
  uniform const unsigned int32 event_number,
  uniform const unsigned int32 number_of_events)
{
  uniform const unsigned int selected_event_number = dev_event_list[event_number];
  uniform const int8* uniform raw_input = dev_raw_input + dev_raw_input_offsets[selected_event_number];
  const unsigned int32* module_cluster_start = dev_module_cluster_start + event_number * Velo_Constants_n_modules;
  unsigned int32* module_cluster_num = dev_module_cluster_num + event_number * Velo_Constants_n_modules;
  uniform unsigned int32 number_of_candidates = dev_event_candidate_num[event_number];
  unsigned int32* cluster_candidates =
    (unsigned int32*) &dev_cluster_candidates[event_number * VeloClustering_max_candidates_event];

  // Local pointers to dev_velo_cluster_container
  const unsigned int32 estimated_number_of_clusters =
    dev_module_cluster_start[Velo_Constants_n_modules * number_of_events];
  float* cluster_xs = (float*) &dev_velo_cluster_container[0];
  float* cluster_ys = (float*) &dev_velo_cluster_container[estimated_number_of_clusters];
  float* cluster_zs = (float*) &dev_velo_cluster_container[2 * estimated_number_of_clusters];
  unsigned int32* cluster_ids = (unsigned int32*) &dev_velo_cluster_container[3 * estimated_number_of_clusters];

  // Load Velo geometry (assume it is the same for all events)
  uniform const VeloGeometry g = VeloGeometry_ctor(dev_velo_geometry);

  // Read raw event
  uniform const VeloRawEvent raw_event = VeloRawEvent_ctor(raw_input);

  // process no neighbour sp
  foreach (raw_bank_number = 0 ... raw_event.number_of_raw_banks) {
    const int32 module_number = raw_bank_number >> 2;
    const unsigned int32 cluster_start = module_cluster_start[module_number];

    // Read raw bank
    const VeloRawBank raw_bank = VeloRawBank_ctor(raw_event.payload + raw_event.raw_bank_offset[raw_bank_number]);
    const float* ltg = g.ltg + 16 * raw_bank.sensor_index;

    for (int sp_index = 0; sp_index < raw_bank.sp_count; ++sp_index) {
      // Decode sp
      const unsigned int32 sp_word = raw_bank.sp_word[sp_index];
      const unsigned int32 sp_addr = (sp_word & 0x007FFF00U) >> 8;
      const unsigned int32 no_sp_neighbours = sp_word & 0x80000000U;

      // There are no neighbours, so compute the number of pixels of this superpixel
      if (no_sp_neighbours) {
        // Look up pre-generated patterns
        const unsigned int32 sp_row = sp_addr & 0x3FU;
        const unsigned int32 sp_col = (sp_addr >> 6);
        const unsigned int8 sp = sp_word & 0xFFU;

        const unsigned int32 idx = dev_velo_sp_patterns[sp];
        const unsigned int32 chip = sp_col / (VP_ChipColumns / 2);

        {
          // there is always at least one cluster in the super
          // pixel. look up the pattern and add it.
          const unsigned int32 row = idx & 0x03U;
          const unsigned int32 col = (idx >> 2) & 1;
          const unsigned int32 cx = sp_col * 2 + col;
          const unsigned int32 cy = sp_row * 4 + row;

          const unsigned int32 cid = get_channel_id(raw_bank.sensor_index, chip, cx % VP_ChipColumns, cy);

          const float fx = dev_velo_sp_fx[sp * 2];
          const float fy = dev_velo_sp_fy[sp * 2];
          const float local_x = g.local_x[cx] + fx * g.x_pitch[cx];
          const float local_y = (cy + 0.5 + fy) * g.pixel_size;

          const unsigned int32 cluster_num = atomic_add_global(module_cluster_num + module_number, 1);

          const float gx = ltg[0] * local_x + ltg[1] * local_y + ltg[9];
          const float gy = ltg[3] * local_x + ltg[4] * local_y + ltg[10];
          const float gz = ltg[6] * local_x + ltg[7] * local_y + ltg[11];

          cluster_xs[cluster_start + cluster_num] = gx;
          cluster_ys[cluster_start + cluster_num] = gy;
          cluster_zs[cluster_start + cluster_num] = gz;
          cluster_ids[cluster_start + cluster_num] = get_lhcb_id(cid);
        }

        // if there is a second cluster for this pattern
        // add it as well.
        if (idx & 8) {
          const unsigned int32 row = (idx >> 4) & 3;
          const unsigned int32 col = (idx >> 6) & 1;
          const unsigned int32 cx = sp_col * 2 + col;
          const unsigned int32 cy = sp_row * 4 + row;

          unsigned int32 cid = get_channel_id(raw_bank.sensor_index, chip, cx % VP_ChipColumns, cy);

          const float fx = dev_velo_sp_fx[sp * 2 + 1];
          const float fy = dev_velo_sp_fy[sp * 2 + 1];
          const float local_x = g.local_x[cx] + fx * g.x_pitch[cx];
          const float local_y = (cy + 0.5 + fy) * g.pixel_size;

          const unsigned int32 cluster_num = atomic_add_global(module_cluster_num + module_number, 1);

          const float gx = ltg[0] * local_x + ltg[1] * local_y + ltg[9];
          const float gy = ltg[3] * local_x + ltg[4] * local_y + ltg[10];
          const float gz = ltg[6] * local_x + ltg[7] * local_y + ltg[11];

          cluster_xs[cluster_start + cluster_num] = gx;
          cluster_ys[cluster_start + cluster_num] = gy;
          cluster_zs[cluster_start + cluster_num] = gz;
          cluster_ids[cluster_start + cluster_num] = get_lhcb_id(cid);
        }
      }
    }
  }

  memory_barrier();

  // Process rest of clusters
  foreach (candidate_number = 0 ... number_of_candidates) {
    const unsigned int32 candidate = cluster_candidates[candidate_number];
    const unsigned int8 sp_index = candidate >> 11;
    const unsigned int8 raw_bank_number = (candidate >> 3) & 0xFF;
    const unsigned int32 module_number = raw_bank_number >> 2;
    const unsigned int8 candidate_k = candidate & 0x7;

    // assert(raw_bank_number < Velo::Constants::n_sensors);

    const VeloRawBank raw_bank = VeloRawBank_ctor(raw_event.payload + raw_event.raw_bank_offset[raw_bank_number]);
    const float* ltg = g.ltg + 16 * raw_bank.sensor_index;
    const unsigned int32 sp_word = raw_bank.sp_word[sp_index];
    const unsigned int32 sp_addr = (sp_word & 0x007FFF00U) >> 8;
    // Note: In the code below, row and col are int32 (not unsigned)
    //       This is not a bug
    const int32 sp_row = sp_addr & 0x3FU;
    const int32 sp_col = sp_addr >> 6;

    // Find candidates that follow this condition:
    // For pixel x, all pixels o should *not* be populated
    // o o
    // x o
    //   o

    // Load the following SPs,
    // where x is the SP containing the possible candidates, o are other SPs:
    // oooo
    // oxoo
    // oooo
    // oooo
    //
    // Each column of SPs are in one unsigned int32
    // Order is from left to right
    //
    // 0: o 1: o 2: o 3: o
    //    o    x    o    o
    //    o    o    o    o
    //    o    o    o    o
    //
    // Order inside an unsigned int32 is from bottom to top. Eg. 1:
    // 3: o
    // 2: x
    // 1: o
    // 0: o
    unsigned int32 pixel_array[3] = {0, 0, 0};

    // sp limits to load
    const int32 sp_row_lower_limit = sp_row - 2;
    const int32 sp_row_upper_limit = sp_row + 1;
    const int32 sp_col_lower_limit = sp_col - 1;
    const int32 sp_col_upper_limit = sp_col + 1;

    // Row limits
    const int32 row_lower_limit = sp_row_lower_limit * 4;
    const int32 col_lower_limit = sp_col_lower_limit * 2;

    // Load SPs
    // Note: We will pick up the current one,
    //       no need to add a special case
    for (unsigned int32 k = 0; k < raw_bank.sp_count; ++k) {
      const unsigned int32 other_sp_word = raw_bank.sp_word[k];
      const unsigned int32 other_no_sp_neighbours = other_sp_word & 0x80000000U;
      if (!other_no_sp_neighbours) {
        const unsigned int32 other_sp_addr = (other_sp_word & 0x007FFF00U) >> 8;
        const int32 other_sp_row = other_sp_addr & 0x3FU;
        const int32 other_sp_col = (other_sp_addr >> 6);
        const unsigned int8 other_sp = other_sp_word & 0xFFU;

        if (
          other_sp_row >= sp_row_lower_limit && other_sp_row <= sp_row_upper_limit &&
          other_sp_col >= sp_col_lower_limit && other_sp_col <= sp_col_upper_limit) {
          const int relative_row = other_sp_row - sp_row_lower_limit;
          const int relative_col = other_sp_col - sp_col_lower_limit;

          // Note: Order is:
          // 15 31
          // 14 30
          // 13 29
          // 12 28
          // 11 27
          // 10 26
          //  9 25
          //  8 24
          //  7 23
          //  6 22
          //  5 21
          //  4 20
          //  3 19
          //  2 18
          //  1 17
          //  0 16
          pixel_array[relative_col] |= (other_sp & 0x0F) << (4 * relative_row) | (other_sp & 0xF0)
                                       << (12 + 4 * relative_row);
        }
      }
    }

    // Work with candidate k
    const unsigned int32 row = sp_row * 4 + (candidate_k % 4);
    const unsigned int32 col = sp_col * 2 + ((unsigned int32) (candidate_k >= 4));

    // Cluster
    // This will contain our building cluster
    // Start it with row, col element active
    unsigned int32 cluster[3] = {0, (unsigned int32)((0x01 << (row - row_lower_limit)) << (16 * (col % 2))), 0};

    // Current cluster being considered for generating the mask
    unsigned int32 working_cluster[3] = {0, cluster[1], 0};

    // Delete pixels in cluster from pixels
    pixel_array[1] &= ~cluster[1];

    // Perform actual clustering
    for (int clustering_iterations = 0; clustering_iterations < VeloClustering_max_clustering_iterations;
         ++clustering_iterations) {
      // Create mask for working cluster
      unsigned int32 pixel_mask[3];
      pixel_mask[0] = current_mask(working_cluster[0]) | mask_from_right_to_left(working_cluster[1]);
      pixel_mask[1] = current_mask(working_cluster[1]) | mask_from_right_to_left(working_cluster[2]) |
                      mask_from_left_to_right(working_cluster[0]);
      pixel_mask[2] = current_mask(working_cluster[2]) | mask_from_left_to_right(working_cluster[1]);

      // Calculate new elements
      working_cluster[0] = pixel_array[0] & pixel_mask[0];
      working_cluster[1] = pixel_array[1] & pixel_mask[1];
      working_cluster[2] = pixel_array[2] & pixel_mask[2];

      if (working_cluster[0] == 0 && working_cluster[1] == 0 && working_cluster[2] == 0) {
        break;
      }

      // Add new elements to cluster
      cluster[0] |= working_cluster[0];
      cluster[1] |= working_cluster[1];
      cluster[2] |= working_cluster[2];

      // Delete elements from pixel array
      pixel_array[0] &= ~cluster[0];
      pixel_array[1] &= ~cluster[1];
      pixel_array[2] &= ~cluster[2];
    }

    // Early break: If there are any pixels
    // active in SPs to the right, then
    // there must be another pixel eventually
    // fulfilling the condition
    if (cluster[2]) {
      continue;
    }

    // Calculate x and y from our formed cluster
    // number of active clusters
    const int n = popcnt((int) (cluster[0])) + popcnt((int) (cluster[1]));

    // Prune repeated clusters
    // Only check for repeated clusters for clusters with at least 3 elements
    bool do_store = true;
    if (n >= 3) {
      // Apply mask for found clusters
      // o o
      // x o
      //   o
      unsigned int32 pixel_mask[4];
      pixel_mask[0] = cluster_current_mask(cluster[0]);
      pixel_mask[1] = cluster_current_mask(cluster[1]) | mask_from_left_to_right(cluster[0]);
      pixel_mask[2] = mask_from_left_to_right(cluster[1]);

      // Do "and not" with found clusters
      // This should return patterns like these:
      // x x
      //   x
      //   x
      working_cluster[0] = pixel_mask[0] & (~cluster[0]);
      working_cluster[1] = pixel_mask[1] & (~cluster[1]);
      working_cluster[2] = pixel_mask[2];

      // Require the four pixels of the pattern in order to
      // get the candidates
      unsigned int32 candidates[2];
      candidates[0] = candidates_current_mask_with_right_clusters(working_cluster[0], working_cluster[1]);
      candidates[1] = candidates_current_mask_with_right_clusters(working_cluster[1], working_cluster[2]);

      // candidates = candidates "and" clusters, to get the real candidates
      candidates[0] &= cluster[0];
      candidates[1] &= cluster[1];

      // Remove our cluster candidate
      const unsigned int32 working_candidate = (0x01 << (row - row_lower_limit)) << (16 * (col % 2));
      candidates[1] ^= working_candidate;

      // Check if there is another candidate with precedence
      if (candidates[0] || candidates[1]) {
        // Precedence:
        // The current candidate should not be considered if there is another candidate
        // with a smaller row, or a bigger column
        //
        // In order to calculate the last part, we can use the following trick:
        // In two's complement:
        // 32:  00100000
        // -32: 11100000
        // ~(-32): 00011111 (the mask we want)
        const int32 negative_working_candidate_mask = ~(-working_candidate);
        const bool working_candidate_under_threshold = working_candidate < 4096;

        // Smaller row on candidates[1]
        unsigned int32 smaller_row_pixel_mask =
          ((unsigned int32) working_candidate_under_threshold) * ((unsigned int32) (0xFFF & negative_working_candidate_mask)) |
          ((unsigned int32) (!working_candidate_under_threshold)) * ((unsigned int32) (0xFFF & (negative_working_candidate_mask >> 16)));
        smaller_row_pixel_mask |= smaller_row_pixel_mask << 16;

        // In order to do the current pixel mask, add the eventual bigger column
        // ie: (add the second column)
        // oo
        // xo
        // oo
        // oo
        const unsigned int32 current_pixel_mask =
          smaller_row_pixel_mask | ((unsigned int32) working_candidate_under_threshold) * 0xFFFF0000;

        // Compute do_store
        do_store = ((candidates[0] & smaller_row_pixel_mask) | (candidates[1] & current_pixel_mask)) == 0;
      }
    }

    if (do_store) {
      // Added value of all x
      const int x = popcnt((int) (cluster[0] & 0x0000FFFF)) * col_lower_limit +
                    popcnt((int) (cluster[0] & 0xFFFF0000)) * (col_lower_limit + 1) +
                    popcnt((int) (cluster[1] & 0x0000FFFF)) * (col_lower_limit + 2) +
                    popcnt((int) (cluster[1] & 0xFFFF0000)) * (col_lower_limit + 3);

      // Transpose momentarily clusters to obtain y in an easier way
      const unsigned int32 transposed_clusters[4] = {
        (cluster[0] & 0x000F000F) | ((cluster[1] & 0x000F000F) << 4),
        ((cluster[0] & 0x00F000F0) >> 4) | (cluster[1] & 0x00F000F0),
        ((cluster[0] & 0x0F000F00) >> 8) | ((cluster[1] & 0x0F000F00) >> 4),
        ((cluster[0] & 0xF000F000) >> 12) | ((cluster[1] & 0xF000F000) >> 8)};

      // Added value of all y
      const int y = popcnt((int) (transposed_clusters[0] & 0x11111111)) * row_lower_limit +
                    popcnt((int) (transposed_clusters[0] & 0x22222222)) * (row_lower_limit + 1) +
                    popcnt((int) (transposed_clusters[0] & 0x44444444)) * (row_lower_limit + 2) +
                    popcnt((int) (transposed_clusters[0] & 0x88888888)) * (row_lower_limit + 3) +
                    popcnt((int) (transposed_clusters[1] & 0x11111111)) * (row_lower_limit + 4) +
                    popcnt((int) (transposed_clusters[1] & 0x22222222)) * (row_lower_limit + 5) +
                    popcnt((int) (transposed_clusters[1] & 0x44444444)) * (row_lower_limit + 6) +
                    popcnt((int) (transposed_clusters[1] & 0x88888888)) * (row_lower_limit + 7) +
                    popcnt((int) (transposed_clusters[2] & 0x11111111)) * (row_lower_limit + 8) +
                    popcnt((int) (transposed_clusters[2] & 0x22222222)) * (row_lower_limit + 9) +
                    popcnt((int) (transposed_clusters[2] & 0x44444444)) * (row_lower_limit + 10) +
                    popcnt((int) (transposed_clusters[2] & 0x88888888)) * (row_lower_limit + 11) +
                    popcnt((int) (transposed_clusters[3] & 0x11111111)) * (row_lower_limit + 12) +
                    popcnt((int) (transposed_clusters[3] & 0x22222222)) * (row_lower_limit + 13) +
                    popcnt((int) (transposed_clusters[3] & 0x44444444)) * (row_lower_limit + 14) +
                    popcnt((int) (transposed_clusters[3] & 0x88888888)) * (row_lower_limit + 15);

      // Note: This n is safe to do division with, will not trigger FPE
      const int safe_n = n>0 ? n : 1;

      const unsigned int32 cx = x / safe_n;
      const unsigned int32 cy = y / safe_n;
      const float one_over_n = 1.f / ((float) safe_n);
      const float fx = x * one_over_n - cx;
      const float fy = y * one_over_n - cy;

      // store target (3D point for tracking)
      const unsigned int32 chip = cx / VP_ChipColumns;

      unsigned int32 cid = get_channel_id(raw_bank.sensor_index, chip, cx % VP_ChipColumns, cy);

      const float local_x = g.local_x[cx] + fx * g.x_pitch[cx];
      const float local_y = (cy + 0.5 + fy) * g.pixel_size;

      const unsigned int32 cluster_num = atomic_add_global(module_cluster_num + module_number, 1);

      const float gx = ltg[0] * local_x + ltg[1] * local_y + ltg[9];
      const float gy = ltg[3] * local_x + ltg[4] * local_y + ltg[10];
      const float gz = ltg[6] * local_x + ltg[7] * local_y + ltg[11];

      const unsigned int32 cluster_start = module_cluster_start[module_number];

      const int32 lhcb_id = get_lhcb_id(cid);

      // assert((cluster_start + cluster_num) < estimated_number_of_clusters);

      cluster_xs[cluster_start + cluster_num] = gx;
      cluster_ys[cluster_start + cluster_num] = gy;
      cluster_zs[cluster_start + cluster_num] = gz;
      cluster_ids[cluster_start + cluster_num] = lhcb_id;
    }
  }
}
