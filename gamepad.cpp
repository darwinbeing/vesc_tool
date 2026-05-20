#include "gamepad.h"
#include <SDL3/SDL.h>
#include <cstdlib>

void Gamepad::ensureInit()
{
    if (!SDL_WasInit(SDL_INIT_GAMEPAD)) {
        SDL_InitSubSystem(SDL_INIT_GAMEPAD);
    }
}

Gamepad::Gamepad(int deviceId, QObject *parent)
    : QObject(parent), mDeviceId(deviceId)
{
    ensureInit();
    mPad = SDL_OpenGamepad(static_cast<SDL_JoystickID>(deviceId));
}

Gamepad::~Gamepad()
{
    if (mPad) {
        SDL_CloseGamepad(mPad);
        mPad = nullptr;
    }
}

double Gamepad::readLogicalAxis(int idx)
{
    if (!mPad) return 0.0;
    SDL_UpdateGamepads();
    if (mAxisOverride.contains(idx)) {
        SDL_Joystick *js = SDL_GetGamepadJoystick(mPad);
        int phys = mAxisOverride.value(idx);
        if (js && phys >= 0 && phys < SDL_GetNumJoystickAxes(js)) {
            return static_cast<double>(SDL_GetJoystickAxis(js, phys)) / 32767.0;
        }
    }
    static const SDL_GamepadAxis logical[4] = {
        SDL_GAMEPAD_AXIS_LEFTX, SDL_GAMEPAD_AXIS_LEFTY,
        SDL_GAMEPAD_AXIS_RIGHTX, SDL_GAMEPAD_AXIS_RIGHTY };
    return static_cast<double>(SDL_GetGamepadAxis(mPad, logical[idx])) / 32767.0;
}

double Gamepad::axisLeftX()  { return readLogicalAxis(0); }
double Gamepad::axisLeftY()  { return readLogicalAxis(1); }
double Gamepad::axisRightX() { return readLogicalAxis(2); }
double Gamepad::axisRightY() { return readLogicalAxis(3); }

void Gamepad::startConfigureAxis(int logicalAxis)
{
    if (!mPad) return;
    SDL_UpdateGamepads();
    mCaptureBaseline.clear();
    SDL_Joystick *js = SDL_GetGamepadJoystick(mPad);
    if (js) {
        int n = SDL_GetNumJoystickAxes(js);
        for (int i = 0; i < n; ++i) mCaptureBaseline.append(SDL_GetJoystickAxis(js, i));
    }
    mConfiguringAxis = logicalAxis;
}

void Gamepad::update()
{
    if (!mPad || mConfiguringAxis < 0) return;
    SDL_UpdateGamepads();
    SDL_Joystick *js = SDL_GetGamepadJoystick(mPad);
    if (!js) return;
    const int THRESH = 16000;            // require a clear deflection
    int n = SDL_GetNumJoystickAxes(js);
    int best = -1, bestDelta = THRESH;
    for (int i = 0; i < n && i < mCaptureBaseline.size(); ++i) {
        int delta = std::abs(static_cast<int>(SDL_GetJoystickAxis(js, i)) - mCaptureBaseline[i]);
        if (delta > bestDelta) { bestDelta = delta; best = i; }
    }
    if (best >= 0) {
        mAxisOverride[mConfiguringAxis] = best;
        int done = mConfiguringAxis;
        mConfiguringAxis = -1;
        emit axisConfigured(done);
    }
}

void Gamepad::resetConfiguration()
{
    mAxisOverride.clear();
    mConfiguringAxis = -1;
}

QString Gamepad::axisMapString() const
{
    QStringList parts;
    for (auto it = mAxisOverride.constBegin(); it != mAxisOverride.constEnd(); ++it)
        parts << QString("%1:%2").arg(it.key()).arg(it.value());
    return parts.join(",");
}

void Gamepad::setAxisMapString(const QString &s)
{
    mAxisOverride.clear();
    const QStringList parts = s.split(",", Qt::SkipEmptyParts);
    for (const QString &p : parts) {
        const QStringList kv = p.split(":");
        if (kv.size() == 2) mAxisOverride[kv[0].toInt()] = kv[1].toInt();
    }
}

bool Gamepad::isConnected()
{
    return mPad && SDL_GamepadConnected(mPad);
}

QString Gamepad::name()
{
    if (!mPad) {
        return QString();
    }
    const char *n = SDL_GetGamepadName(mPad);
    return n ? QString::fromUtf8(n) : QString();
}

QList<int> Gamepad::connectedGamepads()
{
    ensureInit();
    QList<int> ids;
    int count = 0;
    SDL_JoystickID *list = SDL_GetGamepads(&count);
    if (list) {
        for (int i = 0; i < count; ++i) {
            ids.append(static_cast<int>(list[i]));
        }
        SDL_free(list);
    }
    return ids;
}

QString Gamepad::gamepadName(int deviceId)
{
    ensureInit();
    const char *n = SDL_GetGamepadNameForID(static_cast<SDL_JoystickID>(deviceId));
    return n ? QString::fromUtf8(n) : QString();
}
