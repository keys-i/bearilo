#ifndef BEARILO_LINUX_H
#define BEARILO_LINUX_H

typedef void (*bearilo_linux_key_callback)(int key_code, int key_state, const char *key_name, void *user_data);

int bearilo_linux_start(bearilo_linux_key_callback callback, void *user_data);
int bearilo_linux_stop(void);

#endif
