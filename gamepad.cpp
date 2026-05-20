#include "gamepad.h"
#include <SDL3/SDL.h>

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

double Gamepad::axis(int sdlAxis)
{
    if (!mPad) {
        return 0.0;
    }
    SDL_UpdateGamepads();
    Sint16 v = SDL_GetGamepadAxis(mPad, static_cast<SDL_GamepadAxis>(sdlAxis));
    return static_cast<double>(v) / 32767.0;
}

double Gamepad::axisLeftX()  { return axis(SDL_GAMEPAD_AXIS_LEFTX); }
double Gamepad::axisLeftY()  { return axis(SDL_GAMEPAD_AXIS_LEFTY); }
double Gamepad::axisRightX() { return axis(SDL_GAMEPAD_AXIS_RIGHTX); }
double Gamepad::axisRightY() { return axis(SDL_GAMEPAD_AXIS_RIGHTY); }

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
