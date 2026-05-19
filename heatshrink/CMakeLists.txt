target_sources(vesc_tool PRIVATE
    heatshrink_decoder.c heatshrink_encoder.c heatshrinkif.cpp
    heatshrink_common.h heatshrink_config.h heatshrink_decoder.h
    heatshrink_encoder.h heatshrinkif.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
