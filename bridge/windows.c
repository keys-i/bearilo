
#include "windows.h"

#include <windows.h>

static HANDLE listener_thread = 0;
static DWORD listener_thread_id = 0;
static HANDLE listener_started_event = 0;
static HHOOK listener_hook = 0;
static DWORD listener_start_error = ERROR_SUCCESS;
static volatile LONG listener_running = 0;
static bearilo_windows_key_callback listener_callback = 0;
static void *listener_user_data = 0;

static LRESULT CALLBACK keyboard_proc(int code, WPARAM wparam, LPARAM lparam) {
    if (code == HC_ACTION && listener_callback != 0) {
        KBDLLHOOKSTRUCT *event = (KBDLLHOOKSTRUCT *)lparam;
        int state = 2;

        if (wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN) {
            state = 1;
        } else if (wparam == WM_KEYUP || wparam == WM_SYSKEYUP) {
            state = 0;
        }

        listener_callback((int)event->vkCode, state, 0, listener_user_data);
    }

    return CallNextHookEx(listener_hook, code, wparam, lparam);
}

static DWORD WINAPI windows_event_loop(LPVOID parameter) {
    (void)parameter;

    listener_thread_id = GetCurrentThreadId();
    listener_hook = SetWindowsHookExW(WH_KEYBOARD_LL, keyboard_proc, GetModuleHandleW(0), 0);

    if (listener_hook == 0) {
        listener_start_error = GetLastError();
        InterlockedExchange(&listener_running, 0);
        SetEvent(listener_started_event);
        return 1;
    }

    listener_start_error = ERROR_SUCCESS;
    SetEvent(listener_started_event);

    MSG message;
    while (InterlockedCompareExchange(&listener_running, 1, 1) != 0) {
        BOOL result = GetMessageW(&message, 0, 0, 0);
        if (result <= 0) {
            break;
        }

        TranslateMessage(&message);
        DispatchMessageW(&message);
    }

    UnhookWindowsHookEx(listener_hook);
    listener_hook = 0;
    InterlockedExchange(&listener_running, 0);

    return 0;
}

int bearilo_windows_start(bearilo_windows_key_callback callback, void *user_data) {
    if (callback == 0) {
        return ERROR_INVALID_PARAMETER;
    }

    if (InterlockedCompareExchange(&listener_running, 1, 0) != 0) {
        return ERROR_ALREADY_EXISTS;
    }

    listener_callback = callback;
    listener_user_data = user_data;
    listener_start_error = ERROR_SUCCESS;
    listener_started_event = CreateEventW(0, TRUE, FALSE, 0);

    if (listener_started_event == 0) {
        InterlockedExchange(&listener_running, 0);
        listener_callback = 0;
        listener_user_data = 0;
        return GetLastError();
    }

    listener_thread = CreateThread(0, 0, windows_event_loop, 0, 0, &listener_thread_id);
    if (listener_thread == 0) {
        DWORD error = GetLastError();
        CloseHandle(listener_started_event);
        listener_started_event = 0;
        InterlockedExchange(&listener_running, 0);
        listener_callback = 0;
        listener_user_data = 0;
        return (int)error;
    }

    DWORD wait_result = WaitForSingleObject(listener_started_event, 5000);
    CloseHandle(listener_started_event);
    listener_started_event = 0;

    if (wait_result != WAIT_OBJECT_0 || listener_start_error != ERROR_SUCCESS) {
        DWORD error = wait_result == WAIT_OBJECT_0 ? listener_start_error : wait_result;
        WaitForSingleObject(listener_thread, INFINITE);
        CloseHandle(listener_thread);
        listener_thread = 0;
        listener_thread_id = 0;
        listener_callback = 0;
        listener_user_data = 0;
        InterlockedExchange(&listener_running, 0);
        return (int)error;
    }

    return 0;
}

int bearilo_windows_stop(void) {
    if (listener_thread == 0) {
        return 0;
    }

    int result = 0;
    InterlockedExchange(&listener_running, 0);

    if (listener_thread_id != 0 && PostThreadMessageW(listener_thread_id, WM_QUIT, 0, 0) == 0) {
        result = (int)GetLastError();
    }

    DWORD wait_result = WaitForSingleObject(listener_thread, 5000);
    if (wait_result != WAIT_OBJECT_0 && result == 0) {
        result = (int)wait_result;
    }

    CloseHandle(listener_thread);

    listener_thread = 0;
    listener_thread_id = 0;
    listener_callback = 0;
    listener_user_data = 0;

    return result;
}
