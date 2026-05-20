#ifndef GAMEPAD_H
#define GAMEPAD_H

#include <QObject>
#include <QString>
#include <QList>
#include <QMap>
#include <QVector>
#include <QStringList>

struct SDL_Gamepad;

// SDL3-backed gamepad, interface-compatible with the subset of QGamepad/
// QGamepadManager that VESC Tool used. Axis getters return -1.0..1.0.
//
// Logical axis indices: 0=LeftX, 1=LeftY, 2=RightX, 3=RightY.
class Gamepad : public QObject
{
    Q_OBJECT
public:
    explicit Gamepad(int deviceId, QObject *parent = nullptr);
    ~Gamepad() override;

    double axisLeftX();
    double axisLeftY();
    double axisRightX();
    double axisRightY();

    bool isConnected();
    QString name();
    int deviceId() const { return mDeviceId; }

    // Axis remapping (replicates QGamepadManager::configureAxis / resetConfiguration).
    void startConfigureAxis(int logicalAxis);   // begin capturing a physical axis
    void resetConfiguration();                   // clear all overrides
    void update();                               // call each poll tick; drives capture
    bool isConfiguring() const { return mConfiguringAxis >= 0; }
    QString axisMapString() const;               // serialize override map for QSettings
    void setAxisMapString(const QString &s);     // restore override map from QSettings

    // Enumeration (replaces QGamepadManager::connectedGamepads / gamepadName).
    static QList<int> connectedGamepads();
    static QString gamepadName(int deviceId);

signals:
    void axisConfigured(int logicalAxis);

private:
    static void ensureInit();
    double readLogicalAxis(int idx);   // applies override; used by the 4 axis getters

    SDL_Gamepad *mPad = nullptr;
    int mDeviceId = -1;

    int mConfiguringAxis = -1;
    QVector<int> mCaptureBaseline;
    QMap<int,int> mAxisOverride;       // logical axis -> physical joystick axis index
};

#endif // GAMEPAD_H
