# XPENC Local AI: llama.cpp (chat) and whisper.cpp (speech to text), built
# from the pinned sources in third_party/ — nothing is downloaded or
# prebuilt, so F-Droid can build it like the rest of the app.
#
#   third_party/llama.cpp    b11446 (2026-10-06), MIT
#   third_party/whisper.cpp  v1.9.5 (2026-10-06), MIT, built on llama.cpp's
#                            ggml (same 0.26.0) so the app carries one copy
#
# CPU only. GPU backends were left out of the vendored copy on purpose.
cmake_minimum_required(VERSION 3.10)
project(xpenc_local_ai LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# ggml: static, CPU backend only, no runtime CPU probing, no downloads.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(GGML_STATIC OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL OFF CACHE BOOL "" FORCE)
set(GGML_CPU ON CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_CPU_KLEIDIAI OFF CACHE BOOL "" FORCE)
set(GGML_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GGML_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
# ggml asks git for "its" commit, which here would be XPENC's own HEAD and
# make every build differ. Skip git (a set GIT_EXE skips find_program; OFF
# reads as false) and stamp the pinned upstream commit instead.
set(GIT_EXE OFF CACHE FILEPATH "" FORCE)
set(GGML_BUILD_COMMIT "a043d38a")
add_subdirectory(third_party/llama.cpp/ggml ggml EXCLUDE_FROM_ALL)

# llama
set(LLAMA_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/llama.cpp)
file(GLOB LLAMA_CORE_SOURCES ${LLAMA_DIR}/src/*.cpp)
file(GLOB LLAMA_MODELS_SOURCES ${LLAMA_DIR}/src/models/*.cpp)
add_library(llama STATIC ${LLAMA_CORE_SOURCES} ${LLAMA_MODELS_SOURCES})
set_target_properties(llama PROPERTIES UNITY_BUILD ON UNITY_BUILD_BATCH_SIZE 16)
set_source_files_properties(${LLAMA_CORE_SOURCES}
  PROPERTIES SKIP_UNITY_BUILD_INCLUSION ON)
set(LLAMA_VERSION "b11446")
set(LLAMA_BUILD_COMMIT "a043d38a")
configure_file(${LLAMA_DIR}/src/llama-version.h.in
  ${CMAKE_CURRENT_BINARY_DIR}/llama-version.h @ONLY)
target_include_directories(llama PRIVATE ${LLAMA_DIR}/src ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(llama PUBLIC ${LLAMA_DIR}/include)
target_link_libraries(llama PUBLIC ggml)

# whisper
set(WHISPER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/whisper.cpp)
add_library(whisper STATIC
  ${WHISPER_DIR}/src/whisper.cpp
  ${WHISPER_DIR}/src/aneforge/whisper-aneforge.cpp)
target_include_directories(whisper PRIVATE ${WHISPER_DIR}/src)
target_include_directories(whisper PUBLIC ${WHISPER_DIR}/include)
target_compile_definitions(whisper PRIVATE WHISPER_VERSION="1.9.5")
find_package(Threads REQUIRED)
target_link_libraries(whisper PUBLIC ggml Threads::Threads)

# The one library Dart opens.
add_library(xpenc_local_ai SHARED xpenc_local_ai.cpp)
set_target_properties(xpenc_local_ai PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN ON)
target_compile_definitions(xpenc_local_ai PRIVATE XAI_BUILD)
target_link_libraries(xpenc_local_ai PRIVATE llama whisper ggml)
if(ANDROID)
  target_link_libraries(xpenc_local_ai PRIVATE log)
  # 16 KB pages (Android 15+, a Play requirement), whatever NDK builds it.
  target_link_options(xpenc_local_ai PRIVATE "-Wl,-z,max-page-size=16384")
endif()
if(NOT APPLE)
  # Only the xai_* surface is exported; llama/ggml/whisper stay internal,
  # and whatever the wrapper never calls is dropped.
  target_link_options(xpenc_local_ai PRIVATE
    "-Wl,--exclude-libs,ALL" "-Wl,--gc-sections")
endif()
