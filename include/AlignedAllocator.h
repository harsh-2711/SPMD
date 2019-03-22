#pragma once

#include <malloc.h>
#include <cstdlib>
#include <new>
#include <vector>

/**
 * Minimal allocator for aligned data.
 *  
 * Based on
 * https://www.youtube.com/watch?v=dTeKf5Oek2c&feature=youtu.be&t=26m27s
 */
template<class T, std::size_t Alignment>
class aligned_allocator
{
public:
  typedef T value_type;

  template<typename U>
  struct rebind {
    using other = aligned_allocator<U, Alignment>;
  };

  aligned_allocator() noexcept {};

  template<class U>
  aligned_allocator(const aligned_allocator<U, Alignment>&) noexcept {}

  bool operator==(const aligned_allocator&) const noexcept {
    return true;
  }

  bool operator!=(const aligned_allocator& other) const noexcept {
    return false;
  }

  T* allocate(const std::size_t n) const {
    // The return value of allocate(0) is unspecified.
    // Mallocator returns NULL in order to avoid depending
    // on malloc(0)'s implementation-defined behavior
    // (the implementation can define malloc(0) to return NULL,
    // in which case the bad_alloc check below would fire).
    // All allocators can return NULL in this case.
    if (n == 0) {
      return nullptr;
    }

    // All allocators should contain an integer overflow check.
    if (n > static_cast<std::size_t>(-1) / sizeof(T)) {
      throw std::bad_array_new_length();
    }

    // Mallocator wraps memalign().
    void * const pv = memalign(Alignment, n * sizeof(T));

    // Allocators should throw std::bad_alloc in the case of memory allocation failure.
    if (pv == NULL) {
      throw std::bad_alloc();
    }

    return static_cast<T*>(pv);
  }

  void deallocate(T * const p, const std::size_t) const noexcept {
    free(p);
  }
};

template<typename T>
using aligned_vector = std::vector<T, aligned_allocator<T, 32>>;
