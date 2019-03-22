#include "common/VeloCommon.ih"

/**
 * @brief Calculates the parameters according to a root means square fit
 *        and returns the chi2.
 */
 float means_square_fit_chi2(
  const float* hit_Xs,
  const float* hit_Ys,
  const float* hit_Zs,
  const Velo_TrackletHits& track
) {
  VeloState state;

  // Fit parameters
  float s0, sx, sz, sxz, sz2;
  float u0, uy, uz, uyz, uz2;
  s0 = sx = sz = sxz = sz2 = 0.0f;
  u0 = uy = uz = uyz = uz2 = 0.0f;

  // Iterate over hits
  for (unsigned int16 h=0; h<3; ++h) {
    const unsigned int16 hitno = track.hits[h];
    const float x = hit_Xs[hitno];
    const float y = hit_Ys[hitno];
    const float z = hit_Zs[hitno];

    const float wx = Velo_Tracking_param_w;
    const float wx_t_x = wx * x;
    const float wx_t_z = wx * z;
    s0 += wx;
    sx += wx_t_x;
    sz += wx_t_z;
    sxz += wx_t_x * z;
    sz2 += wx_t_z * z;

    const float wy = Velo_Tracking_param_w;
    const float wy_t_y = wy * y;
    const float wy_t_z = wy * z;
    u0 += wy;
    uy += wy_t_y;
    uz += wy_t_z;
    uyz += wy_t_y * z;
    uz2 += wy_t_z * z;
  }

  {
    // Calculate tx, ty and backward
    const float dens = 1.0f / (sz2 * s0 - sz * sz);
    state.tx = (sxz * s0 - sx * sz) * dens;
    state.x = (sx * sz2 - sxz * sz) * dens;

    const float denu = 1.0f / (uz2 * u0 - uz * uz);
    state.ty = (uyz * u0 - uy * uz) * denu;
    state.y = (uy * uz2 - uyz * uz) * denu;
  }

  {
    //=========================================================================
    // Chi2 / degrees-of-freedom of straight-line fit
    //=========================================================================
    float ch = 0.0f;
    int nDoF = -4;
    for (unsigned int32 h=0; h<3; ++h) {
      const unsigned int16 hitno = track.hits[h];

      const float z = hit_Zs[hitno];
      const float x = state.x + state.tx * z;
      const float y = state.y + state.ty * z;

      const float dx = x - hit_Xs[hitno];
      const float dy = y - hit_Ys[hitno];

      ch += dx * dx * Velo_Tracking_param_w + dy * dy * Velo_Tracking_param_w;

      // Nice :)
      // TODO: We can get rid of the X and Y read here
      // float sum_w_xzi_2 = CL_Velo_Tracking_param_w * x; // for each hit
      // float sum_w_xi_2 = CL_Velo_Tracking_param_w * hit_Xs[hitno]; // for each hit
      // ch = (sum_w_xzi_2 - sum_w_xi_2) + (sum_w_yzi_2 - sum_w_yi_2);

      nDoF += 2;
    }
    state.chi2 = ch / nDoF;
  }

  return state.chi2;
}

void weak_tracks_adder_impl(
  uniform unsigned int32* uniform weaktracks_insert_pointer,
  uniform unsigned int32* tracks_insert_pointer,
  uniform Velo_TrackletHits* weak_tracks,
  uniform Velo_TrackHits* tracks,
  uniform int8* hit_used,
  uniform const float* hit_Xs,
  uniform const float* hit_Ys,
  uniform const float* hit_Zs
) {
  // Compute the weak tracks
  uniform const unsigned int32 weaktracks_total = weaktracks_insert_pointer[0];
  foreach (weaktrack_no = 0 ... weaktracks_total) {
    const Velo_TrackletHits t = weak_tracks[weaktrack_no];
    const bool any_used = hit_used[t.hits[0]] == 1 || hit_used[t.hits[1]] == 1 || hit_used[t.hits[2]] == 1;
    const float chi2 = means_square_fit_chi2(
      hit_Xs,
      hit_Ys,
      hit_Zs,
      t
    );

    // Store them in the tracks bag
    if (!any_used && chi2 < Velo_Tracking_max_chi2) {
      const unsigned int32 trackno = atomic_add_global(tracks_insert_pointer, 1);
      // assert(trackno < Velo_Constants_max_tracks);
      tracks[trackno] = Velo_TrackHits_ctor(weak_tracks, weaktrack_no);
    }
  }
}

export void weak_tracks_adder(
  uniform float dev_velo_cluster_x [],
  uniform float dev_velo_cluster_y [],
  uniform float dev_velo_cluster_z [],
  uniform unsigned int32 dev_velo_cluster_id [],
  uniform float dev_velo_cluster_phi [],
  uniform unsigned int32 dev_velo_cluster_temp [],
  uniform unsigned int32 dev_module_cluster_start [],
  uniform int8 dev_tracks_param [],
  uniform int8 dev_weak_tracks_param [],
  uniform int8 dev_hit_used [],
  uniform int dev_atomics_velo [],
  uniform const unsigned int32 event_number,
  uniform const unsigned int32 number_of_events
) {
  uniform Velo_TrackHits* dev_tracks = (Velo_TrackHits*) dev_tracks_param;
  uniform Velo_TrackletHits* dev_weak_tracks = (Velo_TrackletHits*) dev_weak_tracks_param;

  // Each event is treated with two blocks, one for each side.
  uniform const unsigned int32 tracks_offset = event_number * Velo_Constants_max_tracks;

  // Pointers to data within the event
  uniform const unsigned int32 number_of_hits = dev_module_cluster_start[Velo_Constants_n_modules * number_of_events];
  uniform const unsigned int32* uniform module_hitStarts = dev_module_cluster_start + event_number * Velo_Constants_n_modules;
  uniform const unsigned int32 hit_offset = module_hitStarts[0];
  // assert((module_hitStarts[52] - module_hitStarts[0]) < Velo_Constants_max_number_of_hits_per_event);

  // Order has changed since SortByPhi
  const float* hit_Ys = (float*) (dev_velo_cluster_x + hit_offset);
  const float* hit_Zs = (float*) (dev_velo_cluster_y + hit_offset);
  const float* hit_Xs = (float*) (dev_velo_cluster_temp + hit_offset);

  // Per event datatypes
  uniform Velo_TrackHits* tracks = dev_tracks + tracks_offset;
  uniform unsigned int32* tracks_insert_pointer = (unsigned int32*) dev_atomics_velo + event_number;

  // Per side datatypes
  uniform int8* hit_used = dev_hit_used + hit_offset;
  uniform Velo_TrackletHits* weak_tracks = dev_weak_tracks + event_number * Velo_Tracking_max_weak_tracks;

  // Initialize variables according to event number and module side
  // Insert pointers (atomics)
  uniform const int ip_shift = number_of_events + event_number * (Velo_num_atomics - 1);
  uniform unsigned int32* uniform weaktracks_insert_pointer = (unsigned int32*) dev_atomics_velo + ip_shift;

  weak_tracks_adder_impl(
    weaktracks_insert_pointer,
    tracks_insert_pointer,
    weak_tracks,
    tracks,
    hit_used,
    hit_Xs,
    hit_Ys,
    hit_Zs
  );
}
