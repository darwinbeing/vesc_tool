#ifndef GAMEPAD_H
#define GAMEPAD_H

#include <QObject>
#include <QString>
#include <QList>

struct SDL_Gamepad;

// SDL3-backed gamepad, interface-compatible with the subset of QGamepad/
// QGamepadManager that VESC Tool used. Axis getters return -1.0..1.0.
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

    // Enumeration (replaces QGamepadManager::connectedGamepads / gamepadName).
    static QList<int> connectedGamepads();
    static QString gamepadName(int deviceId);

private:
    static void ensureInit();
    double axis(int sdlAxis);

    SDL_Gamepad *mPad = nullptr;
    int mDeviceId = -1;
};

#endif // GAMEPAD_H
