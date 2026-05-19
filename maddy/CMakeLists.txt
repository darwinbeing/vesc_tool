# maddy is header-only; expose its headers on the include path.
target_include_directories(vesc_tool PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..)
