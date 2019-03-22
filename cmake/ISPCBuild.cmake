macro(_expand_sources VAR)
  #message(STATUS "Expand ${ARGN} in ${VAR}")
  set(${VAR})
  foreach(fp ${ARGN})
    file(GLOB files src/${fp})
    if(files)
      set(${VAR} ${${VAR}} ${files})
    else()
      file(GLOB files ${fp})
      if(files)
        set(${VAR} ${${VAR}} ${files})
      else()
        set(${VAR} ${${VAR}} ${fp})
      endif()
    endif()
  endforeach()
  #message(STATUS "  result: ${${VAR}}")
endmacro()

function(add_ispc_library name)
  set(multiValueArgs ISPC_IA_TARGETS ISPC_ARM_TARGETS ISPC_FLAGS)
  cmake_parse_arguments(ARG "${options}" "" "${multiValueArgs}" ${ARGN})

  _expand_sources(srcs ${ARG_UNPARSED_ARGUMENTS})

  set(ISPC_KNOWN_TARGETS "sse2" "sse4" "avx1-" "avx1.1" "avx2" "avx512knl" "avx512skx")
  set(ISPC_ARCH "x86-64")

  file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${name}/ispc)

  execute_process( COMMAND bash "-c" "uname -m | sed -e s/x86_64/x86/ -e s/i686/x86/ -e s/arm.*/arm/ -e s/sa110/arm/" OUTPUT_VARIABLE ARCH)
  string(STRIP ${ARCH} ARCH)
  execute_process( COMMAND getconf LONG_BIT OUTPUT_VARIABLE ARCH_BIT)
  string(STRIP ${ARCH_BIT} ARCH_BIT)
  if (${ARCH_BIT} EQUAL 32)
    set(ISPC_ARCH "x86")
  else()
    set(ISPC_ARCH "x86-64")
  endif()

  # Collect list of expected outputs
  foreach (ispc_src ${srcs})
    string(REGEX REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/(.*)\\.ispc$" "\\1" ispc_src_name ${ispc_src})
    set(ISPC_HEADER "${CMAKE_CURRENT_BINARY_DIR}/${name}/${ispc_src_name}_ispc.h")
    set(ISPC_OBJ "${CMAKE_CURRENT_BINARY_DIR}/${name}/${ispc_src_name}_ispc${CMAKE_CXX_OUTPUT_EXTENSION}")

    list(APPEND ${ispc_src_name}_ISPC_BUILD_OUTPUT ${ISPC_HEADER} ${ISPC_OBJ})
    # message(STATUS "output ${${ispc_src_name}_ISPC_BUILD_OUTPUT})")
    if ("${ARCH}" STREQUAL "x86")
      set(ISPC_TARGETS ${ARG_ISPC_IA_TARGETS})
      string(FIND ${ARG_ISPC_IA_TARGETS} "," MULTI_TARGET)
      if (${MULTI_TARGET} GREATER -1)
        foreach (ispc_target ${ISPC_KNOWN_TARGETS})
          string(FIND ${ARG_ISPC_IA_TARGETS} ${ispc_target} FOUND_TARGET)
          if (${FOUND_TARGET} GREATER -1)
            set(OUTPUT_TARGET ${ispc_target})
            if (${ispc_target} STREQUAL "avx1-")
              set(OUTPUT_TARGET "avx")
            elseif (${ispc_target} STREQUAL "avx1.1")
              set(OUTPUT_TARGET "avx11")
            endif()
            list(APPEND ${ispc_src_name}_ISPC_BUILD_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}/${ispc_src_name}_ispc_${OUTPUT_TARGET}.h"
              "${CMAKE_CURRENT_BINARY_DIR}/${name}/${ispc_src_name}_ispc_${OUTPUT_TARGET}${CMAKE_CXX_OUTPUT_EXTENSION}")
          endif()
        endforeach()
      endif()
    elseif ("${ISPC_ARCH}" STREQUAL "arm")
      set(ISPC_TARGETS ${${NAME}_args}_ISPC_ARM_TARGETS})
    else()
      message(FATAL_ERROR "Unknown architecture ${ARCH}")
    endif()

    # make directory
    get_filename_component(dir "${ISPC_HEADER}" DIRECTORY)
    string(REPLACE "/" "_" directory_tgt ${ispc_src_name}_directory)
    add_custom_target(${directory_tgt} ALL COMMAND ${CMAKE_COMMAND} -E make_directory "${dir}")

    # ISPC command
    add_custom_command(OUTPUT ${${ispc_src_name}_ISPC_BUILD_OUTPUT}
      COMMAND ${ISPC_EXECUTABLE} ${ispc_src}
      ${ARG_ISPC_FLAGS} --target=${ISPC_TARGETS} --arch=${ISPC_ARCH}
      -h ${ISPC_HEADER} -o ${ISPC_OBJ}
      VERBATIM
      DEPENDS ${ispc_src} ${directory_tgt})
    list(APPEND ISPC_OBJS ${ISPC_OBJ})
  endforeach()

  add_library(${name} STATIC ${ISPC_OBJS} ${srcs})
  target_include_directories(${name} PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/${name}/ispc)
  # set_target_properties(${name} PROPERTIES
  #   SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
  #   REQUIRED_INCLUDE_DIRS "${ARG_INCLUDE_DIRS};${CMAKE_CURRENT_BINARY_DIR}/${name}/ispc"
  #   REQUIRED_LIBRARIES "${ARG_LINK_LIBRARIES}")

  set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
  set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)

endfunction()
