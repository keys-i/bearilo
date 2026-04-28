#ifndef BEARILO_DARWIN_H
#define BEARILO_DARWIN_H

typedef void (*bearilo_darwin_key_callback)(int key_code, int key_state, const char *key_name, void *user_data);

int bearilo_darwin_start(bearilo_darwin_key_callback callback, void *user_data);
int bearilo_darwin_stop(void);

#endif
