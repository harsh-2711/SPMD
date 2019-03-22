#include "BinarySearchFirstCandidate.ih"

int binary_search_first_candidate(
  const float* array,
  const unsigned int32 array_size,
  const float& value,
  const float margin
) {
  bool found = false;
  int l = 0;
  int r = array_size - 1;
  while (l < r) {
    const int m = (l + r) / 2;
    const float array_element = array[m];
    found |= abs(value - array_element) < margin;
    if (value - margin > array_element) {
      l = m + 1;
    } else {
      r = m;
    }
  }
  found |= abs(value - array[l]) < margin;
  return found ? l : -1;
}

int binary_search_second_candidate(
  const float* array,
  const unsigned int32 array_size,
  const float& value,
  const float margin
) {
  int l = 0;
  int r = array_size - 1;
  while (l < r) {
    const int m = (l + r) / 2;
    if (value + margin > array[m]) {
      l = m + 1;
    } else {
      r = m;
    }
  }
  const bool last_compatible = abs(value - array[l]) < margin;
  return last_compatible ? l+1 : l;
}
