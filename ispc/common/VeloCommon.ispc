#include "VeloCommon.ih"

uniform const unsigned int32 Velo_Constants_n_modules = 52;
uniform const unsigned int32 VP_ChipColumns = 256;

uniform const unsigned int32 VeloClustering_mask_bottom = 0xFFFEFFFF;
uniform const unsigned int32 VeloClustering_mask_top = 0xFFFF7FFF;
uniform const unsigned int32 VeloClustering_mask_top_left = 0x7FFF7FFF;
uniform const unsigned int32 VeloClustering_mask_bottom_right = 0xFFFEFFFE;
uniform const unsigned int32 VeloClustering_mask_ltr_top_right = 0x7FFF0000;
uniform const unsigned int32 VeloClustering_mask_rtl_bottom_left = 0x0000FFFE;
uniform const unsigned int32 VeloClustering_max_clustering_iterations = 12;
uniform const unsigned int32 VeloClustering_lookup_table_size = 9;
uniform const unsigned int32 VeloClustering_max_candidates_event = 3000;

// uniform const float Velo_Tracking_phi_extrapolation = 0.0436332f;
uniform const float Velo_Tracking_phi_extrapolation = 0.062f;
// uniform const float Velo_Tracking_phi_extrapolation = 0.0959931f;
uniform const float Velo_Tracking_forward_phi_tolerance = 0.052f;
uniform const float Velo_Tracking_max_slope = 0.4f;
uniform const float Velo_Tracking_tolerance = 0.6f;
uniform const float Velo_Tracking_max_scatter_seeding = 0.004f;
uniform const float Velo_Tracking_max_scatter_forwarding = 0.004f;
uniform const unsigned int32 Velo_Tracking_max_skipped_modules = 1;
uniform const unsigned int32 Velo_Tracking_ttf_modulo = 2000;
uniform const unsigned int32 Velo_Tracking_max_weak_tracks = 500;
uniform const unsigned int32 Velo_Tracking_states_per_track = 3;
uniform const float Velo_Tracking_param_w = 3966.94f;
uniform const float Velo_Tracking_param_w_inverted = 0.000252083f;
uniform const float Velo_Tracking_max_chi2 = 20.0f;

uniform const unsigned int32 Velo_Constants_max_tracks = 1200;
uniform const unsigned int32 Velo_Constants_max_numhits_in_module = 500;
uniform const unsigned int32 Velo_num_atomics = 5;

uniform const float FLT_MAX = 3.402823466e+38f;

uniform VeloGeometry VeloGeometry_ctor(uniform const int8* uniform geometry)
{
  uniform VeloGeometry velo_geometry;

  uniform const int8* uniform p = geometry;
  velo_geometry.number_of_sensors = *((unsigned int32*) p);
  p += sizeof(uniform unsigned int32);
  velo_geometry.number_of_sensor_columns = *((unsigned int32*) p);
  p += sizeof(uniform unsigned int32);
  velo_geometry.number_of_sensors_per_module = *((unsigned int32*) p);
  p += sizeof(uniform unsigned int32);
  velo_geometry.chip_columns = *((unsigned int32*) p);
  p += sizeof(uniform unsigned int32);
  velo_geometry.local_x = (double*) p;
  p += sizeof(uniform double) * velo_geometry.number_of_sensor_columns;
  velo_geometry.x_pitch = (double*) p;
  p += sizeof(uniform double) * velo_geometry.number_of_sensor_columns;
  velo_geometry.pixel_size = *((float*) p);
  p += sizeof(uniform float);
  velo_geometry.ltg = (float*) p;
  p += sizeof(uniform float) * 16 * velo_geometry.number_of_sensors;
  velo_geometry.size = p - geometry;

  return velo_geometry;
}

unsigned int32 get_channel_id(unsigned int sensor, unsigned int chip, unsigned int col, unsigned int row)
{
  uniform const unsigned int32 LHCb_VPChannelID_colBits = 8;
  uniform const unsigned int32 LHCb_VPChannelID_chipBits = 16;
  uniform const unsigned int32 LHCb_VPChannelID_sensorBits = 18;

  return (sensor << LHCb_VPChannelID_sensorBits) | (chip << LHCb_VPChannelID_chipBits) |
         (col << LHCb_VPChannelID_colBits) | row;
}

int32 get_lhcb_id(int32 cid)
{
  uniform const unsigned int32 LHCb_VPChannelID_VP = 8;
  uniform const unsigned int32 LHCb_detectorTypeBits = 28;

  return (LHCb_VPChannelID_VP << LHCb_detectorTypeBits) + cid;
}

Velo_Module Velo_Module_ctor(
  const unsigned int32 _hitStart,
  const unsigned int32 _hitNums,
  const float _z)
{
  Velo_Module module;
  module.hitStart = _hitStart;
  module.hitNums = _hitNums;
  module.z = _z;
  return module;
}

Velo_HitBase Velo_HitBase_ctor(
  const float x,
  const float y,
  const float z)
{
  Velo_HitBase h;
  h.x = x;
  h.y = y;
  h.z = z;
  return h;
}

Velo_Hit Velo_Hit_ctor(
  const float x,
  const float y,
  const float z,
  const unsigned int32 LHCbID)
{
  Velo_Hit h;
  h.x = x;
  h.y = y;
  h.z = z;
  h.LHCbID = LHCbID;
  return h;
}

Velo_TrackletHits Velo_TrackletHits_ctor(
  const unsigned int16 h0,
  const unsigned int16 h1,
  const unsigned int16 h2)
{
  Velo_TrackletHits tracklet_hits;
  tracklet_hits.hits[0] = h0;
  tracklet_hits.hits[1] = h1;
  tracklet_hits.hits[2] = h2;
  return tracklet_hits;
}

Velo_TrackHits Velo_TrackHits_ctor(
  const unsigned int16 h0,
  const unsigned int16 h1,
  const unsigned int16 h2)
{
  Velo_TrackHits track_hits;
  track_hits.hitsNum = 3;
  track_hits.hits[0] = h0;
  track_hits.hits[1] = h1;
  track_hits.hits[2] = h2;
  return track_hits;
}

Velo_TrackHits Velo_TrackHits_ctor(
  const Velo_TrackletHits* tracklet_hits,
  const unsigned int32 tracklet_number)
{
  Velo_TrackHits track_hits;
  track_hits.hitsNum = 3;
  track_hits.hits[0] = tracklet_hits[tracklet_number].hits[0];
  track_hits.hits[1] = tracklet_hits[tracklet_number].hits[1];
  track_hits.hits[2] = tracklet_hits[tracklet_number].hits[2];
  return track_hits;
}

Velo_Track Velo_Track_ctor()
{
  Velo_Track track;
  track.hitsNum = 0;
  return track;
}
