#include "linux.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>

static pthread_t listener_thread;
static int listener_started = 0;
static int listener_running = 0;
static int listener_fd = -1;
static bearilo_linux_key_callback listener_callback = 0;
static void *listener_user_data = 0;

static int open_first_event_device(void) {
    int last_error = ENOENT;

    for (int index = 0; index < 64; index++) {
        char path[64];
        snprintf(path, sizeof(path), "/dev/input/event%d", index);

        int fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd >= 0) {
            return fd;
        }

        if (errno == EACCES) {
            last_error = EACCES;
        } else if (last_error != EACCES) {
            last_error = errno;
        }
    }

    errno = last_error;
    return -1;
}

static void *linux_event_loop(void *unused) {
    (void)unused;

    while (listener_running) {
        struct pollfd poll_fd;
        poll_fd.fd = listener_fd;
        poll_fd.events = POLLIN;
        poll_fd.revents = 0;

        int poll_result = poll(&poll_fd, 1, 100);
        if (poll_result < 0) {
            if (errno != EINTR) {
                listener_running = 0;
            }
            continue;
        }

        if (poll_result == 0 || !(poll_fd.revents & POLLIN)) {
            continue;
        }

        struct input_event event;
        ssize_t bytes_read = read(listener_fd, &event, sizeof(event));
        if (bytes_read != sizeof(event)) {
            if (bytes_read < 0 && errno != EAGAIN && errno != EINTR) {
                listener_running = 0;
            }
            continue;
        }

        if (event.type == EV_KEY && listener_callback != 0) {
            int state = 2;
            if (event.value == 1) {
                state = 1;
            } else if (event.value == 0) {
                state = 0;
            }

            listener_callback((int)event.code, state, 0, listener_user_data);
        }
    }

    return 0;
}

int bearilo_linux_start(bearilo_linux_key_callback callback, void *user_data) {
    if (callback == 0) {
        return EINVAL;
    }

    if (listener_started) {
        return EALREADY;
    }

    listener_fd = open_first_event_device();
    if (listener_fd < 0) {
        return errno;
    }

    listener_callback = callback;
    listener_user_data = user_data;
    listener_running = 1;

    int thread_error = pthread_create(&listener_thread, 0, linux_event_loop, 0);
    if (thread_error != 0) {
        close(listener_fd);
        listener_fd = -1;
        listener_running = 0;
        listener_callback = 0;
        listener_user_data = 0;
        return thread_error;
    }

    listener_started = 1;
    return 0;
}

int bearilo_linux_stop(void) {
    if (!listener_started) {
        return 0;
    }

    listener_running = 0;

    int join_error = pthread_join(listener_thread, 0);

    if (listener_fd >= 0) {
        close(listener_fd);
    }

    listener_fd = -1;
    listener_started = 0;
    listener_callback = 0;
    listener_user_data = 0;

    return join_error;
}
