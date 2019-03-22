#include "common/VeloCommon.ih"

export void estimate_input_size(
  uniform const int8 dev_raw_input [],
  uniform const unsigned int dev_raw_input_offsets [],
  uniform unsigned int dev_estimated_input_size [],
  uniform unsigned int dev_event_candidate_num [],
  uniform unsigned int dev_cluster_candidates [],
  uniform const unsigned int dev_event_list [],
  uniform const unsigned int8 dev_velo_candidate_ks [],
  uniform const unsigned int event_number)
{
  uniform const unsigned int selected_event_number = dev_event_list[event_number];
  uniform const int8* uniform raw_input = dev_raw_input + dev_raw_input_offsets[selected_event_number];
  uniform unsigned int* estimated_input_size = dev_estimated_input_size + event_number * Velo_Constants_n_modules;
  uniform unsigned int* event_candidate_num = dev_event_candidate_num + event_number;
  unsigned int* cluster_candidates = dev_cluster_candidates + event_number * VeloClustering_max_candidates_event;

  // Read raw event
  uniform const VeloRawEvent raw_event = VeloRawEvent_ctor(raw_input);

  // foreach (raw_bank_number = 0 ... raw_event.number_of_raw_banks) {
  for (uniform int raw_bank_number = 0; raw_bank_number < raw_event.number_of_raw_banks; ++raw_bank_number) {
    // Read raw bank
    uniform const VeloRawBank raw_bank = VeloRawBank_ctor(raw_event.payload + raw_event.raw_bank_offset[raw_bank_number]);

    unsigned int* estimated_module_size = estimated_input_size + (raw_bank.sensor_index >> 2);
    foreach (sp_index = 0 ... raw_bank.sp_count) {
    // for (int sp_index = programIndex; sp_index < raw_bank.sp_count; sp_index+=programCount) {
      // Decode sp
      const unsigned int sp_word = raw_bank.sp_word[sp_index];
      const unsigned int no_sp_neighbours = sp_word & 0x80000000U;
      const unsigned int sp_addr = (sp_word & 0x007FFF00U) >> 8;
      const unsigned int8 sp = sp_word & 0xFFU;

      if (no_sp_neighbours) {
        // The SP does not have any neighbours
        // The problem is as simple as a lookup pattern
        // It can be implemented in two operations

        // Pattern 0:
        // (x  x)
        //  o  o
        // (x  x
        //  x  x)
        //
        // Note: Pixel order in sp
        // 0x08 | 0x80
        // 0x04 | 0x40
        // 0x02 | 0x20
        // 0x01 | 0x10
        const bool pattern_0 = (sp & 0x88) && !(sp & 0x44) && sp & 0x33;

        // Pattern 1:
        // (x  x
        //  x  x)
        //  o  o
        // (x  x)
        const bool pattern_1 = (sp & 0xCC) && !(sp & 0x22) && sp & 0x11;
        const unsigned int number_of_clusters = 1 + ((int) (pattern_0 | pattern_1));

        // Add the found clusters
        unsigned int current_estimated_module_size = atomic_add_global(estimated_module_size, number_of_clusters);
        // assert( current_estimated_module_size < VELO_CONSTANTS_max_numhits_in_module);
      }
      else {
        // Find candidates that follow this condition:
        // For pixel o, all pixels x should *not* be populated
        // x x
        // o x
        //   x

        // Load required neighbouring pixels in order to check the condition
        // x x x
        // o o x
        // o o x
        // o o x
        // o o x
        //   x x
        //
        // Use an int for storing and calculating
        // Bit order
        //
        // 4 10 16
        // 3  9 15
        // 2  8 14
        // 1  7 13
        // 0  6 12
        //    5 11
        //
        // Bit masks
        //
        // 0x10 0x0400 0x010000
        // 0x08 0x0200   0x8000
        // 0x04 0x0100   0x4000
        // 0x02   0x80   0x2000
        // 0x01   0x40   0x1000
        //        0x20   0x0800
        unsigned int pixels = (sp & 0x0F) | ((sp & 0xF0) << 2);

        // Current row and col
        const unsigned int sp_row = sp_addr & 0x3FU;
        const unsigned int sp_col = sp_addr >> 6;

        for (unsigned int k = 0; k < raw_bank.sp_count; ++k) {
          const unsigned int other_sp_word = raw_bank.sp_word[k];
          const unsigned int other_no_sp_neighbours = sp_word & 0x80000000U;

          if (!other_no_sp_neighbours) {
            const unsigned int other_sp_addr = (other_sp_word & 0x007FFF00U) >> 8;
            const unsigned int other_sp_row = other_sp_addr & 0x3FU;
            const unsigned int other_sp_col = (other_sp_addr >> 6);
            const unsigned int8 other_sp = other_sp_word & 0xFFU;

            // Populate pixels
            // Note: Pixel order in sp
            // 0x08 | 0x80
            // 0x04 | 0x40
            // 0x02 | 0x20
            // 0x01 | 0x10
            const int8 is_top = other_sp_row == (sp_row + 1) && other_sp_col == sp_col;
            const int8 is_top_right = other_sp_row == (sp_row + 1) && other_sp_col == (sp_col + 1);
            const int8 is_right = other_sp_row == sp_row && other_sp_col == (sp_col + 1);
            const int8 is_right_bottom = other_sp_row == (sp_row - 1) && other_sp_col == (sp_col + 1);
            const int8 is_bottom = other_sp_row == (sp_row - 1) && other_sp_col == sp_col;

            if (is_top || is_top_right || is_right || is_right_bottom || is_bottom) {
              pixels |= is_top * ((other_sp & 0x01 | ((other_sp & 0x10) << 2)) << 4);
              pixels |= is_top_right * ((other_sp & 0x01) << 16);
              pixels |= is_right * ((other_sp & 0x0F) << 12);
              pixels |= is_right_bottom * ((other_sp & 0x08) << 8);
              pixels |= is_bottom * ((other_sp & 0x80) >> 2);
            }
          }
        }

        // 16 1024 65536
        //  8  512 32768
        //  4  256 16384
        //  2  128  8192
        //  1   64  4096
        //      32  2048
        //
        // Look up pattern
        // x x
        // o x
        //   x
        //
        unsigned int found_cluster_candidates = 0;

        // assert(raw_bank_number < VELO_CONSTANTS_n_sensors);

        const unsigned int sp_inside_pixel = pixels & 0x3CF;
        const unsigned int mask =
          (sp_inside_pixel << 1) | (sp_inside_pixel << 5) | (sp_inside_pixel << 6) | (sp_inside_pixel << 7);

        const unsigned int working_cluster = mask & (~pixels);
        const unsigned int candidates_temp =
          (working_cluster >> 1) & (working_cluster >> 5) & (working_cluster >> 6) & (working_cluster >> 7);

        const unsigned int candidates = candidates_temp & pixels;

        const unsigned int8 candidates_uint8 = (candidates & 0x03) | ((candidates & 0xC0) >> 4) |
                                         ((candidates & 0x0C) << 2) | ((candidates & 0x0300) >> 2);

        // Add candidates 0, 1, 4, 5
        // Only one of those candidates can be flagged at a time
        if (candidates_uint8 & 0xF) {
          // if ((candidates_uint8 & 0xF) >= 9) {
          //   auto print_candidates8 = [] (const unsigned int8& candidates) {
          //     printf("%i%i\n%i%i\n%i%i\n%i%i\n\n",
          //       (candidates & 0x80) > 0, (candidates & 0x40) > 0,
          //       (candidates & 0x20) > 0, (candidates & 0x10) > 0,
          //       (candidates & 0x8) > 0, (candidates & 0x4) > 0,
          //       (candidates & 0x2) > 0, candidates & 0x1
          //     );
          //   };
          //   auto print_candidates = [] (const unsigned int& candidates) {
          //     printf("%i%i%i\n%i%i%i\n%i%i%i\n%i%i%i\n%i%i%i\n %i%i\n\n",
          //       (candidates & 0x10) > 0, (candidates & 0x0400) > 0, (candidates & 0x010000) > 0,
          //       (candidates & 0x08) > 0, (candidates & 0x0200) > 0, (candidates & 0x8000) > 0,
          //       (candidates & 0x04) > 0, (candidates & 0x0100) > 0, (candidates & 0x4000) > 0,
          //       (candidates & 0x02) > 0, (candidates & 0x80) > 0, (candidates & 0x2000) > 0,
          //       (candidates & 0x01) > 0, (candidates & 0x40) > 0, (candidates & 0x1000) > 0,
          //                                (candidates & 0x20) > 0, (candidates & 0x0800) > 0
          //     );
          //   };
          //   printf("pixels:\n");
          //   print_candidates(pixels);
          //   printf("sp_inside_pixel:\n");
          //   print_candidates(sp_inside_pixel);
          //   printf("mask:\n");
          //   print_candidates(mask);
          //   printf("working_cluster:\n");
          //   print_candidates(working_cluster);
          //   printf("candidates:\n");
          //   print_candidates(candidates);
          //   printf("candidates_uint8:\n");
          //   print_candidates8(candidates_uint8);
          // }

          // Verify candidates are correctly created
          // assert((candidates_uint8 & 0xF) < 9);

          // Decode the candidate number (ie. find out the active bit)
          const unsigned int8 k = dev_velo_candidate_ks[candidates_uint8 & 0xF];
          const unsigned int current_cluster_candidate = atomic_add_global(event_candidate_num, 1);
          const unsigned int candidate = (sp_index << 11) | (raw_bank_number << 3) | k;
          // assert(current_cluster_candidate < programCount * VeloClustering_max_candidates_event);
          cluster_candidates[current_cluster_candidate] = candidate;
          ++found_cluster_candidates;
        }

        // Add candidates 2, 3, 6, 7
        // Only one of those candidates can be flagged at a time
        if (candidates_uint8 & 0xF0) {
          // assert(((candidates_uint8 >> 4) & 0xF) < 9);
          const unsigned int8 k = dev_velo_candidate_ks[(candidates_uint8 >> 4)] + 2;
          const unsigned int current_cluster_candidate = atomic_add_global(event_candidate_num, 1);
          const unsigned int candidate = (sp_index << 11) | (raw_bank_number << 3) | k;
          // assert(current_cluster_candidate < programCount * VeloClustering_max_candidates_event);
          cluster_candidates[current_cluster_candidate] = candidate;
          ++found_cluster_candidates;
        }

        // Add the found cluster candidates
        if (found_cluster_candidates > 0) {
          unsigned int current_estimated_module_size =
            atomic_add_global(estimated_module_size, found_cluster_candidates);
          // assert(current_estimated_module_size < VELO_CONSTANTS_max_numhits_in_module);
        }
      }
    }
  }
}

// 34, 17, 54, 52, 29, 23, 44, 18, 23, 65,
// 34, 17, 54, 52, 29, 23, 44, 18, 23, 65,
