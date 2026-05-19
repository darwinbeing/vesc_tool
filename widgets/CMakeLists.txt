target_sources(vesc_tool PRIVATE
    batttempplot.cpp batttempplot.h
    canlistitem.cpp canlistitem.h
    experimentplot.cpp experimentplot.h experimentplot.ui
    parameditbitfield.cpp parameditbitfield.h parameditbitfield.ui
    parameditbool.cpp parameditbool.h parameditbool.ui
    parameditdouble.cpp parameditdouble.h parameditdouble.ui
    parameditenum.cpp parameditenum.h parameditenum.ui
    parameditint.cpp parameditint.h parameditint.ui
    displaybar.cpp displaybar.h
    displaypercentage.cpp displaypercentage.h
    helpdialog.cpp helpdialog.h helpdialog.ui
    mrichtextedit.cpp mrichtextedit.h mrichtextedit.ui
    mtextedit.cpp mtextedit.h
    pagelistitem.cpp pagelistitem.h
    paramtable.cpp paramtable.h
    qcustomplot.cpp qcustomplot.h
    detectbldc.cpp detectbldc.h detectbldc.ui
    batterycalculator.cpp batterycalculator.h batterycalculator.ui
    detectfoc.cpp detectfoc.h detectfoc.ui
    detectfocencoder.cpp detectfocencoder.h detectfocencoder.ui
    detectfochall.cpp detectfochall.h detectfochall.ui
    ppmmap.cpp ppmmap.h ppmmap.ui
    adcmap.cpp adcmap.h adcmap.ui
    rtdatatext.cpp rtdatatext.h
    nrfpair.cpp nrfpair.h nrfpair.ui
    scripteditor.cpp scripteditor.h scripteditor.ui
    vtextbrowser.cpp vtextbrowser.h
    imagewidget.cpp imagewidget.h
    parameditstring.cpp parameditstring.h parameditstring.ui
    paramdialog.cpp paramdialog.h paramdialog.ui
    aspectimglabel.cpp aspectimglabel.h
    historylineedit.cpp historylineedit.h
    detectallfocdialog.cpp detectallfocdialog.h detectallfocdialog.ui
    dirsetup.cpp dirsetup.h dirsetup.ui
    vesc3dview.cpp vesc3dview.h
    superslider.cpp superslider.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
