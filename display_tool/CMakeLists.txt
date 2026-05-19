target_sources(vesc_tool PRIVATE
    dispeditor.cpp dispeditor.h dispeditor.ui
    displayedit.cpp displayedit.h
    imagewidgetdisp.cpp imagewidgetdisp.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
