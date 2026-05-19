target_sources(vesc_tool PRIVATE
    markdownhighlighter.cpp markdownhighlighter.h
    qmarkdowntextedit.cpp qmarkdowntextedit.h
    qownlanguagedata.cpp qownlanguagedata.h
    qplaintexteditsearchwidget.cpp qplaintexteditsearchwidget.h
    qplaintexteditsearchwidget.ui
    linenumberarea.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

target_sources(vesc_tool PRIVATE media.qrc)
