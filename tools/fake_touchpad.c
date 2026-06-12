/*
 * fake_touchpad.c — a hardware-free gesture injector for testing.
 *
 * Creates a virtual multitouch touchpad via /dev/uinput with enough
 * capabilities that udev tags it ID_INPUT_TOUCHPAD and libinput
 * synthesizes gestures from it (the same trick libinput's own litest
 * test suite uses). Then plays a 3-finger swipe so a libinput client
 * — e.g. our fusuma-libinput-events binary — receives
 * SWIPE_BEGIN/UPDATE/END (event types 800/801/802).
 *
 * Axis ranges mirror a typical Synaptics touchpad (the litest default)
 * so libinput classifies and scales it like real hardware.
 *
 * Usage:
 *   fake_touchpad [gesture] [--hold-ms N]
 *     gesture: swipe (default) | pinch | hold
 *
 * Requires write access to /dev/uinput (the `input` group).
 *
 *   cc -O2 -o fake_touchpad fake_touchpad.c
 *   ./fake_touchpad swipe
 */
#include <linux/uinput.h>
#include <linux/input.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <time.h>

static int ufd;

static void emit(int type, int code, int val)
{
    struct input_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = type;
    ev.code = code;
    ev.value = val;
    if (write(ufd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev)) {
        perror("write");
    }
}

static void syn(void)
{
    emit(EV_SYN, SYN_REPORT, 0);
}

static void sleep_ms(int ms)
{
    struct timespec ts;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (long)(ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

static void setup_abs(int code, int min, int max, int res)
{
    struct uinput_abs_setup abs;
    memset(&abs, 0, sizeof(abs));
    abs.code = code;
    abs.absinfo.minimum = min;
    abs.absinfo.maximum = max;
    abs.absinfo.resolution = res;
    if (ioctl(ufd, UI_ABS_SETUP, &abs) < 0) {
        perror("UI_ABS_SETUP");
    }
}

/* X/Y range of the emulated touchpad (Synaptics-like, units/mm in res) */
#define X_MIN 1472
#define X_MAX 5472
#define X_RES 75
#define Y_MIN 1408
#define Y_MAX 4448
#define Y_RES 129

static void create_device(void)
{
    ufd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (ufd < 0) {
        fprintf(stderr, "open /dev/uinput: %s\n", strerror(errno));
        fprintf(stderr, "  (is your user in the 'input' group?)\n");
        exit(1);
    }

    ioctl(ufd, UI_SET_EVBIT, EV_SYN);
    ioctl(ufd, UI_SET_EVBIT, EV_KEY);
    ioctl(ufd, UI_SET_EVBIT, EV_ABS);

    /* INPUT_PROP_POINTER => touchpad (indirect), not touchscreen */
    ioctl(ufd, UI_SET_PROPBIT, INPUT_PROP_POINTER);

    ioctl(ufd, UI_SET_KEYBIT, BTN_LEFT);
    ioctl(ufd, UI_SET_KEYBIT, BTN_TOUCH);
    ioctl(ufd, UI_SET_KEYBIT, BTN_TOOL_FINGER);
    ioctl(ufd, UI_SET_KEYBIT, BTN_TOOL_DOUBLETAP);
    ioctl(ufd, UI_SET_KEYBIT, BTN_TOOL_TRIPLETAP);
    ioctl(ufd, UI_SET_KEYBIT, BTN_TOOL_QUADTAP);

    ioctl(ufd, UI_SET_ABSBIT, ABS_X);
    ioctl(ufd, UI_SET_ABSBIT, ABS_Y);
    ioctl(ufd, UI_SET_ABSBIT, ABS_MT_SLOT);
    ioctl(ufd, UI_SET_ABSBIT, ABS_MT_POSITION_X);
    ioctl(ufd, UI_SET_ABSBIT, ABS_MT_POSITION_Y);
    ioctl(ufd, UI_SET_ABSBIT, ABS_MT_TRACKING_ID);

    setup_abs(ABS_X, X_MIN, X_MAX, X_RES);
    setup_abs(ABS_Y, Y_MIN, Y_MAX, Y_RES);
    setup_abs(ABS_MT_POSITION_X, X_MIN, X_MAX, X_RES);
    setup_abs(ABS_MT_POSITION_Y, Y_MIN, Y_MAX, Y_RES);
    setup_abs(ABS_MT_SLOT, 0, 2, 0);            /* 3 slots => up to 3 fingers */
    setup_abs(ABS_MT_TRACKING_ID, 0, 65535, 0);

    struct uinput_setup setup;
    memset(&setup, 0, sizeof(setup));
    setup.id.bustype = BUS_I2C;
    setup.id.vendor = 0x0fff;
    setup.id.product = 0x0f5a;
    setup.id.version = 1;
    strcpy(setup.name, "fusuma virtual touchpad");

    if (ioctl(ufd, UI_DEV_SETUP, &setup) < 0) {
        perror("UI_DEV_SETUP");
        exit(1);
    }
    if (ioctl(ufd, UI_DEV_CREATE) < 0) {
        perror("UI_DEV_CREATE");
        exit(1);
    }
}

static void destroy_device(void)
{
    ioctl(ufd, UI_DEV_DESTROY);
    close(ufd);
}

/* Put down `fingers` contacts in a horizontal row at height y. */
static void touch_down(int fingers, int *xs, int y)
{
    int tool = (fingers == 1) ? BTN_TOOL_FINGER
             : (fingers == 2) ? BTN_TOOL_DOUBLETAP
             : (fingers == 3) ? BTN_TOOL_TRIPLETAP
                              : BTN_TOOL_QUADTAP;
    for (int i = 0; i < fingers; i++) {
        emit(EV_ABS, ABS_MT_SLOT, i);
        emit(EV_ABS, ABS_MT_TRACKING_ID, 100 + i);
        emit(EV_ABS, ABS_MT_POSITION_X, xs[i]);
        emit(EV_ABS, ABS_MT_POSITION_Y, y);
    }
    emit(EV_KEY, tool, 1);
    emit(EV_KEY, BTN_TOUCH, 1);
    emit(EV_ABS, ABS_X, xs[0]);
    emit(EV_ABS, ABS_Y, y);
    syn();
}

static void move_to(int fingers, int *xs, int *ys)
{
    for (int i = 0; i < fingers; i++) {
        emit(EV_ABS, ABS_MT_SLOT, i);
        emit(EV_ABS, ABS_MT_POSITION_X, xs[i]);
        emit(EV_ABS, ABS_MT_POSITION_Y, ys[i]);
    }
    emit(EV_ABS, ABS_X, xs[0]);
    emit(EV_ABS, ABS_Y, ys[0]);
    syn();
}

static void lift_all(int fingers)
{
    int tool = (fingers == 1) ? BTN_TOOL_FINGER
             : (fingers == 2) ? BTN_TOOL_DOUBLETAP
             : (fingers == 3) ? BTN_TOOL_TRIPLETAP
                              : BTN_TOOL_QUADTAP;
    for (int i = 0; i < fingers; i++) {
        emit(EV_ABS, ABS_MT_SLOT, i);
        emit(EV_ABS, ABS_MT_TRACKING_ID, -1);
    }
    emit(EV_KEY, tool, 0);
    emit(EV_KEY, BTN_TOUCH, 0);
    syn();
}

/* 3-finger horizontal swipe across the pad. */
static void play_swipe(void)
{
    int fingers = 3;
    int y = 3000;
    int xs[3] = {2600, 3000, 3400};
    touch_down(fingers, xs, y);
    sleep_ms(20);

    int ys[3] = {y, y, y};
    for (int frame = 0; frame < 12; frame++) {
        for (int i = 0; i < fingers; i++) {
            xs[i] += 150;          /* ~24mm total at 75 u/mm */
        }
        move_to(fingers, xs, ys);
        sleep_ms(12);
    }
    lift_all(fingers);
}

/* 2-finger pinch (fingers move apart). */
static void play_pinch(void)
{
    int fingers = 2;
    int y = 3000;
    int xs[2] = {3200, 3300};
    int ys[2] = {y, y};
    touch_down(fingers, xs, y);
    sleep_ms(20);
    for (int frame = 0; frame < 12; frame++) {
        xs[0] -= 120;
        xs[1] += 120;
        ys[0] -= 30;
        ys[1] += 30;
        move_to(fingers, xs, ys);
        sleep_ms(12);
    }
    lift_all(fingers);
}

/*
 * 3-finger hold: fingers down, held still, then lifted.
 *
 * libinput enters its "unknown" gesture state on finger-down and only
 * resolves to HOLD after the fingers stay still past the hold timeout.
 * A single down frame followed by silence resolves too late, so we
 * re-emit the (unchanged) positions periodically to give libinput
 * continuous "still" evidence while its timer runs.
 */
static void play_hold(int hold_ms)
{
    int fingers = 3;
    int y = 3000;
    int xs[3] = {2600, 3000, 3400};
    int ys[3] = {y, y, y};
    touch_down(fingers, xs, y);

    int elapsed = 0;
    while (elapsed < hold_ms) {
        sleep_ms(20);
        move_to(fingers, xs, ys);   /* same coords: "still" */
        elapsed += 20;
    }
    lift_all(fingers);
}

int main(int argc, char **argv)
{
    const char *gesture = (argc > 1) ? argv[1] : "swipe";
    int hold_ms = 400;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--hold-ms") == 0 && i + 1 < argc) {
            hold_ms = atoi(argv[++i]);
        }
    }

    create_device();
    /* give udev + libinput time to enumerate the new device */
    sleep_ms(1500);

    if (strcmp(gesture, "swipe") == 0) {
        play_swipe();
    } else if (strcmp(gesture, "pinch") == 0) {
        play_pinch();
    } else if (strcmp(gesture, "hold") == 0) {
        play_hold(hold_ms);
    } else {
        fprintf(stderr, "unknown gesture: %s (use swipe|pinch|hold)\n", gesture);
        destroy_device();
        return 2;
    }

    sleep_ms(300);
    destroy_device();
    return 0;
}
