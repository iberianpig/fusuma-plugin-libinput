/*
 * shim.c — C glue for things spinel's FFI cannot express.
 *
 * spinel FFI has no struct declarations and no Ruby->C function
 * pointers, so the three pieces below stay in C:
 *
 *   - libinput_interface (open_restricted / close_restricted are
 *     function pointers libinput calls back into)
 *   - struct pollfd (poll needs a struct argument)
 *   - prctl(PR_SET_PDEATHSIG) setup
 *
 * Everything else in the libinput API is plain scalar/pointer calls
 * and is bound directly from Ruby via spinel `ffi_func`.
 */
#include <libinput.h>
#include <libudev.h>
#include <stdio.h>
#include <poll.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <sys/prctl.h>

static int shim_open_restricted(const char *path, int flags, void *user_data)
{
    (void)user_data;
    int fd = open(path, flags);
    return fd < 0 ? -errno : fd;
}

static void shim_close_restricted(int fd, void *user_data)
{
    (void)user_data;
    close(fd);
}

static const struct libinput_interface shim_interface = {
    .open_restricted = shim_open_restricted,
    .close_restricted = shim_close_restricted,
};

/*
 * udev_new -> libinput_udev_create_context(&iface, NULL, udev)
 *          -> libinput_udev_assign_seat(li, seat).
 * Returns the libinput context, or NULL on any failure (caller emits a
 * fatal JSON line and exits).
 */
void *shim_libinput_create(const char *seat)
{
    struct udev *udev = udev_new();
    if (!udev) {
        return NULL;
    }

    struct libinput *li =
        libinput_udev_create_context(&shim_interface, NULL, udev);
    if (!li) {
        udev_unref(udev);
        return NULL;
    }

    if (libinput_udev_assign_seat(li, seat ? seat : "seat0") != 0) {
        libinput_unref(li);
        udev_unref(udev);
        return NULL;
    }

    /*
     * libinput keeps its own ref on udev; drop ours so the context owns
     * the lifetime. (matches libinput's own debug tools.)
     */
    udev_unref(udev);
    return li;
}

/*
 * poll() wrapper that hides struct pollfd. timeout_ms < 0 blocks
 * forever. Returns 1 = readable, 0 = timeout, negative = -errno.
 * EINTR is retried transparently.
 */
int shim_wait_fd(int fd, int timeout_ms)
{
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = POLLIN;

    for (;;) {
        pfd.revents = 0;
        int rc = poll(&pfd, 1, timeout_ms);
        if (rc < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -errno;
        }
        return rc;
    }
}

/*
 * Ask the kernel to send us SIGTERM when our parent (fusuma) dies, so a
 * crashed fusuma never leaves this reader orphaned.
 */
void shim_setup(void)
{
    prctl(PR_SET_PDEATHSIG, SIGTERM);
}

/*
 * Flush stdout. Bound here rather than via a direct fflush ffi_func
 * because spinel's runtime already includes <stdio.h>, and a
 * void*-typed fflush extern would conflict with the FILE* prototype.
 */
void shim_flush(void)
{
    fflush(NULL);
}
