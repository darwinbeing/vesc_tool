target_sources(vesc_tool PRIVATE
    src/internal/LispHighlighter.cpp
    src/internal/QCodeEditor.cpp
    src/internal/QCXXHighlighter.cpp
    src/internal/QFramedTextAttribute.cpp
    src/internal/QGLSLCompleter.cpp
    src/internal/QGLSLHighlighter.cpp
    src/internal/QJSONHighlighter.cpp
    src/internal/QLanguage.cpp
    src/internal/QLineNumberArea.cpp
    src/internal/QLispCompleter.cpp
    src/internal/QLuaCompleter.cpp
    src/internal/QLuaHighlighter.cpp
    src/internal/QPythonCompleter.cpp
    src/internal/QPythonHighlighter.cpp
    src/internal/QStyleSyntaxHighlighter.cpp
    src/internal/QSyntaxStyle.cpp
    src/internal/QXMLHighlighter.cpp
    src/internal/QmlHighlighter.cpp
    src/internal/QVescCompleter.cpp
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
