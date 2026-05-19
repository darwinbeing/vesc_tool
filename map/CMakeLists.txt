target_sources(vesc_tool PRIVATE
    carinfo.cpp carinfo.h
    copterinfo.cpp copterinfo.h
    locpoint.cpp locpoint.h
    mapwidget.cpp mapwidget.h
    osmclient.cpp osmclient.h
    osmtile.cpp osmtile.h
    perspectivepixmap.cpp perspectivepixmap.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
