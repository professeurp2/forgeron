cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "speech_to_text_windows")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must not be changed
set(PLUGIN_NAME "speech_to_text_windows_plugin")

list(APPEND PLUGIN_SOURCES
  "speech_to_text_windows_plugin.cpp"
  "speech_to_text_windows_plugin.h"
)

# Define the plugin library target
add_library(${PLUGIN_NAME} SHARED
  "include/speech_to_text_windows/speech_to_text_windows.h"
  "speech_to_text_windows.cpp"
  ${PLUGIN_SOURCES}
)

# Apply standard Flutter plugin settings
apply_standard_settings(${PLUGIN_NAME})

# Set C++ standard
set_property(TARGET ${PLUGIN_NAME} PROPERTY CXX_STANDARD 17)
set_property(TARGET ${PLUGIN_NAME} PROPERTY CXX_STANDARD_REQUIRED ON)

# Configure target properties
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)

# Define preprocessor macros
target_compile_definitions(${PLUGIN_NAME} PRIVATE 
  FLUTTER_PLUGIN_IMPL
  WIN32_LEAN_AND_MEAN
  NOMINMAX
  _CRT_SECURE_NO_WARNINGS      # Disable CRT security warnings
  _WINSOCK_DEPRECATED_NO_WARNINGS  # Disable deprecated Winsock warnings
)

# Disable specific warnings that are treated as errors
if(MSVC)
  target_compile_options(${PLUGIN_NAME} PRIVATE 
    /utf-8
    /wd4996  # Disable 'function was declared deprecated' warnings
    /wd4245  # Disable signed/unsigned mismatch warnings
    /W3      # Use warning level 3 instead of 4
  )
  # Also apply these settings to the main runner target if possible
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4996")
endif()

# Include directories
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Make sure the plugin headers are available with correct path
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}"
)

# Link Flutter libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  flutter 
  flutter_wrapper_plugin
)

# Link Windows SAPI libraries (without ATL)
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  ole32           # For COM
  oleaut32        # For COM automation
  uuid            # For GUIDs
  sapi            # For Speech API
)

# Forgeron : la dictée SAPI tourne dans ce petit programme séparé (voir
# dictation_helper.cpp et README-FORGERON.md) ; dans le processus de
# l'application, elle refusait de démarrer (0x88890008).
add_executable(forgeron_dictation "dictation_helper.cpp")
target_compile_definitions(forgeron_dictation PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX UNICODE _UNICODE)
target_compile_options(forgeron_dictation PRIVATE /utf-8)
target_link_libraries(forgeron_dictation PRIVATE ole32 oleaut32 uuid sapi)
add_dependencies(${PLUGIN_NAME} forgeron_dictation)

# Copié à côté de l'exécutable de l'application, où le plugin le cherche.
set(speech_to_text_windows_bundled_libraries
  "$<TARGET_FILE:forgeron_dictation>"
  PARENT_SCOPE
)