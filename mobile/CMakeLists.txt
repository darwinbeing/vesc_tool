target_sources(vesc_tool PRIVATE
    logreader.cpp logreader.h
    logwriter.cpp logwriter.h
    qmlui.cpp qmlui.h
    fwhelper.cpp fwhelper.h
    vesc3ditem.cpp vesc3ditem.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
