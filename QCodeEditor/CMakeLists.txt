target_sources(vesc_tool PRIVATE
    include/internal/LispHighlighter.hpp
    include/internal/QCodeEditor.hpp
    include/internal/QCXXHighlighter.hpp
    include/internal/QFramedTextAttribute.hpp
    include/internal/QGLSLCompleter.hpp
    include/internal/QGLSLHighlighter.hpp
    include/internal/QHighlightBlockRule.hpp
    include/internal/QHighlightRule.hpp
    include/internal/QJSONHighlighter.hpp
    include/internal/QLanguage.hpp
    include/internal/QLineNumberArea.hpp
    include/internal/QLispCompleter.hpp
    include/internal/QLuaCompleter.hpp
    include/internal/QLuaHighlighter.hpp
    include/internal/QPythonCompleter.hpp
    include/internal/QPythonHighlighter.hpp
    include/internal/QStyleSyntaxHighlighter.hpp
    include/internal/QSyntaxStyle.hpp
    include/internal/QXMLHighlighter.hpp
    include/internal/QmlHighlighter.hpp
    include/internal/QVescCompleter.hpp
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

target_sources(vesc_tool PRIVATE resources/qcodeeditor_resources.qrc)
