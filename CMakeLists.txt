cmake_minimum_required(VERSION 3.12)
project(VeLoSPMD CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/ISPCBuild.cmake)

find_program (ISPC_EXECUTABLE ispc)
if (NOT ISPC_EXECUTABLE)
  message(FATAL_ERROR "Failed to find ispc" )
else()
  message(STATUS "Found ispc: ${ISPC_EXECUTABLE}" )
endif()

option(ENABLE_CHECKING FALSE)

include_directories(include)
file(GLOB common_sources ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp)

set(TARGET_SOURCES ${common_sources} ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)
# set(ISPC_IA_TARGETS "sse4-i32x4")
# set(ISPC_IA_TARGETS "sse4-i8x16")
# set(ISPC_IA_TARGETS "avx1-i32x4")
# set(ISPC_IA_TARGETS "avx1-i32x16")
# set(ISPC_IA_TARGETS "avx1.1-i64x2")
# set(ISPC_IA_TARGETS "avx1.1-i32x8")
set(ISPC_IA_TARGETS "avx2-i32x8")
# set(ISPC_IA_TARGETS "avx2-i32x16")
# set(ISPC_IA_TARGETS "avx2-i64x4")
# set(ISPC_IA_TARGETS "avx512skx-i32x16")

# Build type
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif(NOT CMAKE_BUILD_TYPE)

if(${CMAKE_BUILD_TYPE} STREQUAL RelWithDebInfo)
  set(ISPC_FLAGS "-O2" "--opt=fast-math" "--wno-perf" "-g")
elseif(${CMAKE_BUILD_TYPE} STREQUAL Release)
  set(ISPC_FLAGS "-O2" "--opt=fast-math" "--math-lib=fast" "--wno-perf" "-g")
elseif(${CMAKE_BUILD_TYPE} STREQUAL RelWithASM)
  set(ISPC_FLAGS "-O2" "--opt=fast-math" "--wno-perf" "-g" "--emit-asm" "--x86-asm-syntax=intel")
elseif(${CMAKE_BUILD_TYPE} STREQUAL Debug)
  set(ISPC_FLAGS "-O0" "-g")
endif()
set(ISPC_FLAGS "${ISPC_FLAGS}" "-I${CMAKE_CURRENT_SOURCE_DIR}/ispc")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=native -O2 -no-pie")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -lpthread")

add_ispc_library(VeloReconstructionLib
  ispc/common/*.ispc
  ispc/utils/*.ispc
  ispc/calculate_phi_and_sort/*.ispc
  ispc/fill_candidates/*.ispc
  ispc/mask_clustering/*.ispc
  ispc/search_by_triplet/*.ispc
  ispc/weak_tracks_adder/*.ispc
  ISPC_IA_TARGETS ${ISPC_IA_TARGETS}
  ISPC_FLAGS ${ISPC_FLAGS})

target_include_directories(VeloReconstructionLib PRIVATE ispc)
add_executable(VeloReconstruction ${TARGET_SOURCES})
target_link_libraries(VeloReconstruction PRIVATE VeloReconstructionLib)

if (ENABLE_CHECKING)
  add_library(Checker STATIC
    checker/src/CategoriesTrackChecker.cpp
    checker/src/MCAssociator.cpp
    checker/src/PrepareTracks.cpp
    checker/src/CheckerInvoker.cpp
	checker/src/MCEvent.cpp
    checker/src/TrackChecker.cpp)

  target_include_directories(Checker PUBLIC checker/include)
  target_link_libraries(VeloReconstruction PRIVATE Checker)

  find_package(ROOT COMPONENTS Core Cling Hist Gpad QUIET)
  if (ROOT_FOUND)
    message(STATUS "Found ROOT project")
    target_compile_definitions(Checker PRIVATE "HAVE_ROOT=1")
    target_include_directories(Checker PRIVATE ${ROOT_INCLUDE_DIRS})
    target_link_libraries(Checker PRIVATE ${ROOT_LIBRARIES})
  endif()
endif()
