#include "PrepareTracks.h"
#include "InputTools.h"
#include "MCParticle.h"
#include "TrackChecker.h"
#include "Tracks.h"

// Part 2 update function signature
std::vector<trackChecker::Tracks> prepareVeloTracks(
  const uint* track_atomics,
  const uint* track_hit_number,
  const char* track_hits,
  const uint number_of_events)
{
  // Tracks to be checked, save in format for checker
  std::vector<trackChecker::Tracks> checker_tracks;
  checker_tracks.reserve(number_of_events);

  for (uint i_event = 0; i_event < number_of_events; i_event++) {
    // all tracks within one event
    trackChecker::Tracks tracks;

    // Part 2:
    // - Add all hit_IDs of a given track to a corresponding trackChecker::Track;
    // - Add all tracks in an event to tracks
    // - Add tracks to checker_tracks;
    /*
    } */
    const Velo::Consolidated::Tracks velo_tracks {
      (uint*) track_atomics, (uint*) track_hit_number, i_event, number_of_events };
      
    const uint number_of_tracks_event = velo_tracks.number_of_tracks(i_event);

    for (uint i_track = 0; i_track < number_of_tracks_event; i_track++) {
      trackChecker::Track t;
      t.p = 0.f;

      const uint velo_track_number_of_hits = velo_tracks.number_of_hits(i_track);
      Velo::Consolidated::Hits velo_track_hits = velo_tracks.get_hits((char*) track_hits, i_track);

      for (int i_hit = 0; i_hit < velo_track_number_of_hits; ++i_hit) {
        t.addId(velo_track_hits.LHCbID[i_hit]);
      }
      tracks.push_back(t);
    } 
    checker_tracks.emplace_back(tracks);
  }

  return checker_tracks;
}
