#include <QtQml/qqmlprivate.h>
#include <QtCore/qdir.h>
#include <QtCore/qurl.h>

static const unsigned char qt_resource_tree[] = {
0,
0,0,0,0,2,0,0,0,1,0,0,0,1,0,0,0,
8,0,2,0,0,0,23,0,0,0,2,0,0,1,188,0,
0,0,0,0,1,0,0,0,0,0,0,0,192,0,0,0,
0,0,1,0,0,0,0,0,0,1,226,0,0,0,0,0,
1,0,0,0,0,0,0,0,246,0,0,0,0,0,1,0,
0,0,0,0,0,2,0,0,0,0,0,0,1,0,0,0,
0,0,0,0,220,0,0,0,0,0,1,0,0,0,0,0,
0,0,66,0,0,0,0,0,1,0,0,0,0,0,0,0,
26,0,0,0,0,0,1,0,0,0,0,0,0,1,114,0,
0,0,0,0,1,0,0,0,0,0,0,0,126,0,0,0,
0,0,1,0,0,0,0,0,0,0,92,0,0,0,0,0,
1,0,0,0,0,0,0,1,24,0,0,0,0,0,1,0,
0,0,0,0,0,2,166,0,0,0,0,0,1,0,0,0,
0,0,0,2,126,0,0,0,0,0,1,0,0,0,0,0,
0,0,170,0,0,0,0,0,1,0,0,0,0,0,0,2,
86,0,0,0,0,0,1,0,0,0,0,0,0,2,254,0,
0,0,0,0,1,0,0,0,0,0,0,2,204,0,0,0,
0,0,1,0,0,0,0,0,0,3,24,0,0,0,0,0,
1,0,0,0,0,0,0,1,72,0,0,0,0,0,1,0,
0,0,0,0,0,3,58,0,0,0,0,0,1,0,0,0,
0,0,0,2,46,0,0,0,0,0,1,0,0,0,0,0,
0,1,158,0,0,0,0,0,1,0,0,0,0};
static const unsigned char qt_resource_names[] = {
0,
1,0,0,0,47,0,47,0,6,7,69,144,37,0,109,0,
111,0,98,0,105,0,108,0,101,0,17,4,30,213,28,0,
68,0,101,0,116,0,101,0,99,0,116,0,70,0,111,0,
99,0,72,0,97,0,108,0,108,0,46,0,113,0,109,0,
108,0,10,3,139,165,60,0,65,0,100,0,99,0,77,0,
97,0,112,0,46,0,113,0,109,0,108,0,14,5,145,51,
188,0,67,0,111,0,110,0,110,0,101,0,99,0,116,0,
66,0,108,0,101,0,46,0,113,0,109,0,108,0,19,5,
23,65,28,0,80,0,97,0,114,0,97,0,109,0,69,0,
100,0,105,0,116,0,68,0,111,0,117,0,98,0,108,0,
101,0,46,0,113,0,109,0,108,0,8,8,1,90,92,0,
109,0,97,0,105,0,110,0,46,0,113,0,109,0,108,0,
11,0,240,239,252,0,76,0,111,0,103,0,103,0,105,0,
110,0,103,0,46,0,113,0,109,0,108,0,10,3,137,186,
124,0,80,0,112,0,109,0,77,0,97,0,112,0,46,0,
113,0,109,0,108,0,14,1,145,156,188,0,70,0,105,0,
108,0,101,0,80,0,105,0,99,0,107,0,101,0,114,0,
46,0,113,0,109,0,108,0,21,5,174,120,220,0,67,0,
111,0,110,0,110,0,101,0,99,0,116,0,66,0,108,0,
101,0,70,0,111,0,114,0,109,0,46,0,117,0,105,0,
46,0,113,0,109,0,108,0,18,11,105,247,188,0,68,0,
101,0,116,0,101,0,99,0,116,0,70,0,111,0,99,0,
80,0,97,0,114,0,97,0,109,0,46,0,113,0,109,0,
108,0,19,4,123,7,124,0,80,0,97,0,114,0,97,0,
109,0,69,0,100,0,105,0,116,0,83,0,116,0,114,0,
105,0,110,0,103,0,46,0,113,0,109,0,108,0,12,15,
38,128,60,0,84,0,101,0,114,0,109,0,105,0,110,0,
97,0,108,0,46,0,113,0,109,0,108,0,16,0,117,151,
124,0,80,0,97,0,114,0,97,0,109,0,69,0,100,0,
105,0,116,0,73,0,110,0,116,0,46,0,113,0,109,0,
108,0,12,1,33,221,124,0,70,0,119,0,85,0,112,0,
100,0,97,0,116,0,101,0,46,0,113,0,109,0,108,0,
20,2,155,78,188,0,68,0,101,0,116,0,101,0,99,0,
116,0,70,0,111,0,99,0,69,0,110,0,99,0,111,0,
100,0,101,0,114,0,46,0,113,0,109,0,108,0,17,13,
18,34,60,0,68,0,111,0,117,0,98,0,108,0,101,0,
83,0,112,0,105,0,110,0,66,0,111,0,120,0,46,0,
113,0,109,0,108,0,17,8,115,103,28,0,80,0,97,0,
114,0,97,0,109,0,69,0,100,0,105,0,116,0,66,0,
111,0,111,0,108,0,46,0,113,0,109,0,108,0,17,7,
148,103,188,0,80,0,97,0,114,0,97,0,109,0,69,0,
100,0,105,0,116,0,69,0,110,0,117,0,109,0,46,0,
113,0,109,0,108,0,16,6,184,151,124,0,80,0,97,0,
114,0,97,0,109,0,69,0,100,0,105,0,116,0,111,0,
114,0,115,0,46,0,113,0,109,0,108,0,22,8,173,195,
28,0,80,0,97,0,114,0,97,0,109,0,69,0,100,0,
105,0,116,0,83,0,101,0,112,0,97,0,114,0,97,0,
116,0,111,0,114,0,46,0,113,0,109,0,108,0,10,8,
171,105,124,0,82,0,116,0,68,0,97,0,116,0,97,0,
46,0,113,0,109,0,108,0,14,11,81,190,124,0,67,0,
111,0,110,0,102,0,105,0,103,0,80,0,97,0,103,0,
101,0,46,0,113,0,109,0,108,0,14,11,245,23,188,0,
68,0,101,0,116,0,101,0,99,0,116,0,66,0,108,0,
100,0,99,0,46,0,113,0,109,0,108};
static const unsigned char qt_resource_empty_payout[] = { 0, 0, 0, 0, 0 };
QT_BEGIN_NAMESPACE
extern Q_CORE_EXPORT bool qRegisterResourceData(int, const unsigned char *, const unsigned char *, const unsigned char *);
QT_END_NAMESPACE
namespace QmlCacheGeneratedCode {
namespace _mobile_DetectBldc_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ConfigPage_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_RtData_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ParamEditSeparator_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ParamEditors_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ParamEditEnum_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ParamEditBool_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_DoubleSpinBox_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_DetectFocEncoder_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_FwUpdate_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ParamEditInt_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_Terminal_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ParamEditString_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_DetectFocParam_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ConnectBleForm_ui_0x2e_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_FilePicker_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_PpmMap_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_Logging_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_main_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ParamEditDouble_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_ConnectBle_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_AdcMap_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}
namespace _mobile_DetectFocHall_qml { 
    extern const unsigned char qmlData[];
    const QQmlPrivate::CachedQmlUnit unit = {
        reinterpret_cast<const QV4::CompiledData::Unit*>(&qmlData), nullptr, nullptr
    };
}

}
namespace {
struct Registry {
    Registry();
    ~Registry();
    QHash<QString, const QQmlPrivate::CachedQmlUnit*> resourcePathToCachedUnit;
    static const QQmlPrivate::CachedQmlUnit *lookupCachedUnit(const QUrl &url);
};

Q_GLOBAL_STATIC(Registry, unitRegistry)


Registry::Registry() {
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/DetectBldc.qml"), &QmlCacheGeneratedCode::_mobile_DetectBldc_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ConfigPage.qml"), &QmlCacheGeneratedCode::_mobile_ConfigPage_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/RtData.qml"), &QmlCacheGeneratedCode::_mobile_RtData_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ParamEditSeparator.qml"), &QmlCacheGeneratedCode::_mobile_ParamEditSeparator_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ParamEditors.qml"), &QmlCacheGeneratedCode::_mobile_ParamEditors_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ParamEditEnum.qml"), &QmlCacheGeneratedCode::_mobile_ParamEditEnum_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ParamEditBool.qml"), &QmlCacheGeneratedCode::_mobile_ParamEditBool_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/DoubleSpinBox.qml"), &QmlCacheGeneratedCode::_mobile_DoubleSpinBox_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/DetectFocEncoder.qml"), &QmlCacheGeneratedCode::_mobile_DetectFocEncoder_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/FwUpdate.qml"), &QmlCacheGeneratedCode::_mobile_FwUpdate_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ParamEditInt.qml"), &QmlCacheGeneratedCode::_mobile_ParamEditInt_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/Terminal.qml"), &QmlCacheGeneratedCode::_mobile_Terminal_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ParamEditString.qml"), &QmlCacheGeneratedCode::_mobile_ParamEditString_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/DetectFocParam.qml"), &QmlCacheGeneratedCode::_mobile_DetectFocParam_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ConnectBleForm.ui.qml"), &QmlCacheGeneratedCode::_mobile_ConnectBleForm_ui_0x2e_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/FilePicker.qml"), &QmlCacheGeneratedCode::_mobile_FilePicker_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/PpmMap.qml"), &QmlCacheGeneratedCode::_mobile_PpmMap_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/Logging.qml"), &QmlCacheGeneratedCode::_mobile_Logging_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/main.qml"), &QmlCacheGeneratedCode::_mobile_main_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ParamEditDouble.qml"), &QmlCacheGeneratedCode::_mobile_ParamEditDouble_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/ConnectBle.qml"), &QmlCacheGeneratedCode::_mobile_ConnectBle_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/AdcMap.qml"), &QmlCacheGeneratedCode::_mobile_AdcMap_qml::unit);
        resourcePathToCachedUnit.insert(QStringLiteral("/mobile/DetectFocHall.qml"), &QmlCacheGeneratedCode::_mobile_DetectFocHall_qml::unit);
    QQmlPrivate::RegisterQmlUnitCacheHook registration;
    registration.version = 0;
    registration.lookupCachedQmlUnit = &lookupCachedUnit;
    QQmlPrivate::qmlregister(QQmlPrivate::QmlUnitCacheHookRegistration, &registration);
QT_PREPEND_NAMESPACE(qRegisterResourceData)(/*version*/0x01, qt_resource_tree, qt_resource_names, qt_resource_empty_payout);
}

Registry::~Registry() {
    QQmlPrivate::qmlunregister(QQmlPrivate::QmlUnitCacheHookRegistration, quintptr(&lookupCachedUnit));
}

const QQmlPrivate::CachedQmlUnit *Registry::lookupCachedUnit(const QUrl &url) {
    if (url.scheme() != QLatin1String("qrc"))
        return nullptr;
    QString resourcePath = QDir::cleanPath(url.path());
    if (resourcePath.isEmpty())
        return nullptr;
    if (!resourcePath.startsWith(QLatin1Char('/')))
        resourcePath.prepend(QLatin1Char('/'));
    return unitRegistry()->resourcePathToCachedUnit.value(resourcePath, nullptr);
}
}
int QT_MANGLE_NAMESPACE(qInitResources_qml)() {
    ::unitRegistry();
    Q_INIT_RESOURCE(mobile_qml_qmlcache);
    return 1;
}
Q_CONSTRUCTOR_FUNCTION(QT_MANGLE_NAMESPACE(qInitResources_qml))
int QT_MANGLE_NAMESPACE(qCleanupResources_qml)() {
    Q_CLEANUP_RESOURCE(mobile_qml_qmlcache);
    return 1;
}
