
#ifndef BEARILO_WINDOWS_H
#define BEARILO_WINDOWS_H

typedef void (*bearilo_windows_key_callback)(int key_code, int key_state, const char *key_name, void *user_data);

int bearilo_windows_start(bearilo_windows_key_callback callback, void *user_data);
int bearilo_windows_stop(void);

#endif
