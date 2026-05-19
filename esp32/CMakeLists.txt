target_sources(vesc_tool PRIVATE
    esp32flash.cpp esp_loader.c esp_targets.c md5_hash.c
    protocol_uart.c protocol_serial.c esp_stubs.c slip.c
    esp32flash.h esp_loader.h esp_targets.h md5_hash.h
    serial_comm_prv.h esp_loader_io.h protocol.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
