/*
  fbdump - copy a framebuffer out through mmap.

  Reading /dev/fb0 with read() is not the same thing as looking at the memory
  the display is scanning out: on some drivers read() comes back zeroed no
  matter what is on screen. This mmaps it instead, so the bytes are the real
  ones, and prints the geometry the driver reports.

  Usage: fbdump [device] [output]
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <linux/fb.h>

int main(int argc, char **argv)
{
    const char *dev = (argc > 1) ? argv[1] : "/dev/fb0";
    const char *out = (argc > 2) ? argv[2] : "/tmp/fb.raw";

    int fd = open(dev, O_RDONLY);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    struct fb_fix_screeninfo fi;
    struct fb_var_screeninfo vi;
    if (ioctl(fd, FBIOGET_FSCREENINFO, &fi) < 0) {
        perror("FBIOGET_FSCREENINFO");
        return 1;
    }
    if (ioctl(fd, FBIOGET_VSCREENINFO, &vi) < 0) {
        perror("FBIOGET_VSCREENINFO");
        return 1;
    }

    fprintf(stderr,
            "fbdump %s: %ux%u visible, %ux%u virtual, bpp %u, stride %u, smem %u, yoffset %u, ypanstep %u\n",
            dev, vi.xres, vi.yres, vi.xres_virtual, vi.yres_virtual,
            vi.bits_per_pixel, fi.line_length, fi.smem_len, vi.yoffset, (unsigned)fi.ypanstep);

    /* The whole mapping, not line_length * yres_virtual: the driver reports a
       larger smem_len, and a present may land anywhere inside it. */
    size_t len = fi.smem_len;
    size_t geom = (size_t)fi.line_length * (size_t)vi.yres_virtual;
    if (len == 0) {
        len = geom;
    }
    if (len == 0) {
        fprintf(stderr, "fbdump: driver reports zero geometry\n");
        return 1;
    }
    fprintf(stderr, "fbdump: geometry %zu bytes, smem %zu bytes, dumping %zu\n", geom, (size_t)fi.smem_len, len);

    unsigned char *p = mmap(NULL, len, PROT_READ, MAP_SHARED, fd, 0);
    if (p == MAP_FAILED) {
        perror("mmap");
        return 1;
    }

    FILE *f = fopen(out, "wb");
    if (!f) {
        perror("fopen");
        return 1;
    }
    size_t written = fwrite(p, 1, len, f);
    fclose(f);

    unsigned long nonzero = 0;
    for (size_t i = 0; i < len; i++) {
        if (p[i]) {
            nonzero++;
        }
    }
    fprintf(stderr, "fbdump: wrote %zu bytes to %s, nonzero %lu\n", written, out, nonzero);

    return 0;
}
