package com.kakario.apprenticetower;

import android.content.Context;
import android.hardware.input.InputManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.webkit.JavascriptInterface;

/**
 * 유선(USB)·무선(블루투스) 게임 컨트롤러 입력을 모아 두었다가 게임(JS)이 매 프레임 읽어 가게 한다.
 * 안드로이드는 연결 방식과 상관없이 컨트롤러를 같은 InputDevice로 다루므로 두 경우 모두 이 경로로 처리된다.
 *
 * 버튼 비트 순서 (게임 쪽 PB 배열과 같아야 함):
 * 0 A, 1 B, 2 X, 3 Y, 4 LB, 5 RB, 6 LT, 7 RT, 8 SELECT, 9 START, 10 L3, 11 R3,
 * 12 위, 13 아래, 14 왼쪽, 15 오른쪽
 */
public class PadBridge implements InputManager.InputDeviceListener {
    private volatile float lx, ly, rx, ry, lt, rt, hx, hy;
    private volatile int buttons;
    private volatile int lastDeviceId = -1;
    private volatile boolean connected;
    private volatile String deviceName = "";
    private final InputManager im;

    PadBridge(Context ctx) {
        im = (InputManager) ctx.getSystemService(Context.INPUT_SERVICE);
        im.registerInputDeviceListener(this, new Handler(Looper.getMainLooper()));
        refreshConnected();
    }

    void release() {
        im.unregisterInputDeviceListener(this);
    }

    // ---------- JS에서 부르는 함수 ----------

    @JavascriptInterface
    public String state() {
        return lx + "," + ly + "," + rx + "," + ry + "," + lt + "," + rt + "," + hx + "," + hy + "," + buttons + "," + (connected ? 1 : 0);
    }

    @JavascriptInterface
    public String name() {
        return deviceName;
    }

    @JavascriptInterface
    public void rumble(int ms, float strength) {
        try {
            InputDevice d = InputDevice.getDevice(lastDeviceId);
            if (d == null) return;
            Vibrator v = null;
            if (Build.VERSION.SDK_INT >= 31) {
                VibratorManager vm = d.getVibratorManager();
                int[] ids = vm.getVibratorIds();
                if (ids.length > 0) v = vm.getVibrator(ids[0]);
            } else {
                v = d.getVibrator();
            }
            if (v == null || !v.hasVibrator()) return;
            int amp = Math.max(1, Math.min(255, Math.round(strength * 255)));
            v.vibrate(VibrationEffect.createOneShot(Math.max(10, ms), amp));
        } catch (Exception ignored) {
        }
    }

    // ---------- 입력 처리 ----------

    static boolean isPadDevice(InputDevice d) {
        if (d == null || d.isVirtual()) return false;
        int s = d.getSources();
        return (s & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
                || (s & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK;
    }

    private static int bitFor(int code) {
        switch (code) {
            case KeyEvent.KEYCODE_BUTTON_A: return 0;
            case KeyEvent.KEYCODE_BUTTON_B: return 1;
            case KeyEvent.KEYCODE_BACK: return 1;          // 일부 컨트롤러는 B를 뒤로가기로 보냄
            case KeyEvent.KEYCODE_BUTTON_X: return 2;
            case KeyEvent.KEYCODE_BUTTON_Y: return 3;
            case KeyEvent.KEYCODE_BUTTON_L1: return 4;
            case KeyEvent.KEYCODE_BUTTON_R1: return 5;
            case KeyEvent.KEYCODE_BUTTON_L2: return 6;
            case KeyEvent.KEYCODE_BUTTON_R2: return 7;
            case KeyEvent.KEYCODE_BUTTON_SELECT: return 8;
            case KeyEvent.KEYCODE_BUTTON_START: return 9;
            case KeyEvent.KEYCODE_MENU: return 9;
            case KeyEvent.KEYCODE_BUTTON_THUMBL: return 10;
            case KeyEvent.KEYCODE_BUTTON_THUMBR: return 11;
            case KeyEvent.KEYCODE_DPAD_UP: return 12;
            case KeyEvent.KEYCODE_DPAD_DOWN: return 13;
            case KeyEvent.KEYCODE_DPAD_LEFT: return 14;
            case KeyEvent.KEYCODE_DPAD_RIGHT: return 15;
            case KeyEvent.KEYCODE_DPAD_CENTER: return 0;
            // 이름 없는 번호 버튼만 보내는 일부 범용 컨트롤러
            case KeyEvent.KEYCODE_BUTTON_1: return 2;
            case KeyEvent.KEYCODE_BUTTON_2: return 0;
            case KeyEvent.KEYCODE_BUTTON_3: return 1;
            case KeyEvent.KEYCODE_BUTTON_4: return 3;
            case KeyEvent.KEYCODE_BUTTON_5: return 4;
            case KeyEvent.KEYCODE_BUTTON_6: return 5;
            case KeyEvent.KEYCODE_BUTTON_7: return 6;
            case KeyEvent.KEYCODE_BUTTON_8: return 7;
            case KeyEvent.KEYCODE_BUTTON_9: return 8;
            case KeyEvent.KEYCODE_BUTTON_10: return 9;
            case KeyEvent.KEYCODE_BUTTON_11: return 10;
            case KeyEvent.KEYCODE_BUTTON_12: return 11;
            default: return -1;
        }
    }

    /** 컨트롤러 키면 처리하고 true. 그 외(터치 화면 뒤로가기, 키보드)는 false. */
    boolean onKey(KeyEvent e) {
        InputDevice d = e.getDevice();
        boolean fromPad = isPadDevice(d) || KeyEvent.isGamepadButton(e.getKeyCode());
        if (!fromPad) return false;
        int code = e.getKeyCode();
        if (code == KeyEvent.KEYCODE_BUTTON_MODE) return false; // 홈 버튼은 시스템에 맡김
        int bit = bitFor(code);
        if (bit < 0) return false;
        lastDeviceId = e.getDeviceId();
        if (!connected) refreshConnected();
        if (e.getAction() == KeyEvent.ACTION_DOWN) buttons |= (1 << bit);
        else if (e.getAction() == KeyEvent.ACTION_UP) buttons &= ~(1 << bit);
        return true;
    }

    boolean onMotion(MotionEvent e) {
        int src = e.getSource();
        boolean joy = (src & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
                || (src & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD;
        if (!joy || e.getAction() != MotionEvent.ACTION_MOVE) return false;
        InputDevice d = e.getDevice();
        if (d == null) return false;
        lastDeviceId = e.getDeviceId();
        if (!connected) refreshConnected();

        lx = axis(e, d, MotionEvent.AXIS_X);
        ly = axis(e, d, MotionEvent.AXIS_Y);
        // 오른쪽 스틱: 대부분 Z/RZ. Z/RZ가 없는 기기만 RX/RY 사용
        // (일부 기기는 RX/RY에 트리거를 싣기 때문에 무조건 섞으면 안 됨)
        if (d.getMotionRange(MotionEvent.AXIS_Z, src) != null && d.getMotionRange(MotionEvent.AXIS_RZ, src) != null) {
            rx = axis(e, d, MotionEvent.AXIS_Z);
            ry = axis(e, d, MotionEvent.AXIS_RZ);
        } else {
            rx = axis(e, d, MotionEvent.AXIS_RX);
            ry = axis(e, d, MotionEvent.AXIS_RY);
        }
        lt = Math.max(axis(e, d, MotionEvent.AXIS_LTRIGGER), axis(e, d, MotionEvent.AXIS_BRAKE));
        rt = Math.max(axis(e, d, MotionEvent.AXIS_RTRIGGER), axis(e, d, MotionEvent.AXIS_GAS));
        hx = axis(e, d, MotionEvent.AXIS_HAT_X);
        hy = axis(e, d, MotionEvent.AXIS_HAT_Y);
        return true;
    }

    private static float axis(MotionEvent e, InputDevice d, int a) {
        InputDevice.MotionRange r = d.getMotionRange(a, e.getSource());
        if (r == null) return 0f;
        float v = e.getAxisValue(a);
        if (Math.abs(v) <= r.getFlat()) return 0f;
        return v;
    }

    private void refreshConnected() {
        boolean found = false;
        String nm = "";
        for (int id : InputDevice.getDeviceIds()) {
            InputDevice d = InputDevice.getDevice(id);
            if (isPadDevice(d)) {
                found = true;
                nm = d.getName();
                if (lastDeviceId < 0) lastDeviceId = id;
                break;
            }
        }
        connected = found;
        deviceName = nm == null ? "" : nm;
        if (!found) {
            buttons = 0;
            lx = ly = rx = ry = lt = rt = hx = hy = 0f;
        }
    }

    @Override public void onInputDeviceAdded(int deviceId) { refreshConnected(); }
    @Override public void onInputDeviceRemoved(int deviceId) { if (deviceId == lastDeviceId) lastDeviceId = -1; refreshConnected(); }
    @Override public void onInputDeviceChanged(int deviceId) { refreshConnected(); }
}
