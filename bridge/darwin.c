#include "darwin.h"

#include <ApplicationServices/ApplicationServices.h>
#include <errno.h>
#include <pthread.h>

static pthread_t listener_thread;
static int listener_started = 0;
static int listener_running = 0;
static bearilo_darwin_key_callback listener_callback = 0;
static void *listener_user_data = 0;
static CFMachPortRef listener_event_tap = 0;
static CFRunLoopSourceRef listener_source = 0;
static CFRunLoopRef listener_run_loop = 0;

static CGEventRef darwin_event_callback(
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void *user_info
) {
    (void)proxy;
    (void)user_info;

    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (listener_event_tap != 0) {
            CGEventTapEnable(listener_event_tap, true);
        }
        return event;
    }

    if ((type == kCGEventKeyDown || type == kCGEventKeyUp) && listener_callback != 0) {
        int key_code = (int)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        int state = type == kCGEventKeyDown ? 1 : 0;
        listener_callback(key_code, state, 0, listener_user_data);
    }

    return event;
}

static void *darwin_event_loop(void *unused) {
    (void)unused;

    listener_run_loop = CFRunLoopGetCurrent();
    CFRetain(listener_run_loop);

    CFRunLoopAddSource(listener_run_loop, listener_source, kCFRunLoopDefaultMode);
    CGEventTapEnable(listener_event_tap, true);

    while (listener_running) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
    }

    CGEventTapEnable(listener_event_tap, false);
    CFRunLoopRemoveSource(listener_run_loop, listener_source, kCFRunLoopDefaultMode);
    CFRelease(listener_run_loop);
    listener_run_loop = 0;

    return 0;
}

int bearilo_darwin_start(bearilo_darwin_key_callback callback, void *user_data) {
    if (callback == 0) {
        return EINVAL;
    }

    if (listener_started) {
        return EALREADY;
    }

    listener_callback = callback;
    listener_user_data = user_data;

    CGEventMask event_mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
    listener_event_tap =
        CGEventTapCreate(
            kCGSessionEventTap,
            kCGHeadInsertEventTap,
            kCGEventTapOptionListenOnly,
            event_mask,
            darwin_event_callback,
            0
        );

    if (listener_event_tap == 0) {
        listener_callback = 0;
        listener_user_data = 0;
        return EPERM;
    }

    listener_source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, listener_event_tap, 0);
    if (listener_source == 0) {
        CFRelease(listener_event_tap);
        listener_event_tap = 0;
        listener_callback = 0;
        listener_user_data = 0;
        return EIO;
    }

    listener_running = 1;

    int thread_error = pthread_create(&listener_thread, 0, darwin_event_loop, 0);
    if (thread_error != 0) {
        listener_running = 0;
        CFRelease(listener_source);
        CFRelease(listener_event_tap);
        listener_source = 0;
        listener_event_tap = 0;
        listener_callback = 0;
        listener_user_data = 0;
        return thread_error;
    }

    listener_started = 1;
    return 0;
}

int bearilo_darwin_stop(void) {
    if (!listener_started) {
        return 0;
    }

    listener_running = 0;

    if (listener_run_loop != 0) {
        CFRunLoopWakeUp(listener_run_loop);
    }

    int join_error = pthread_join(listener_thread, 0);

    if (listener_source != 0) {
        CFRelease(listener_source);
    }

    if (listener_event_tap != 0) {
        CFRelease(listener_event_tap);
    }

    listener_started = 0;
    listener_source = 0;
    listener_event_tap = 0;
    listener_callback = 0;
    listener_user_data = 0;

    return join_error;
}
