#include <libtinyc.h>
#include <stdint.h>

// fixed point precision, bits for fractional part
const uint32_t SHIFT = 24;
const uint32_t PIXELS_X = 40;
const uint32_t PIXELS_Y = 30;

// originally based on https://rosettacode.org/wiki/Mandelbrot_set#B
void renderMandel(int32_t xmin, int32_t dx, int32_t ymin, int32_t dy, uint32_t maxiter)
{

    int32_t cy = ymin;
    for (int32_t ypos = 0; ypos < PIXELS_Y; ++ypos) {
        int32_t cx = xmin;
        for (int32_t xpos = 0; xpos < PIXELS_X; ++xpos) {
            int32_t x = 0;
            int32_t y = 0;
            int32_t x2 = 0;
            int32_t y2 = 0;
            int32_t iter = 0;

            while (iter < maxiter) {
                if (x2 + y2 > (4 << SHIFT))
                    break;

                // prescale multiplicants to ensure result fits in int32_t
                int32_t x_scaled = x >> (SHIFT / 2);
                int32_t y_scaled = y >> (SHIFT / 2);
                y = x_scaled * y_scaled;
                y += y; // times two
                y += cy;

                x = (x2 - y2) + cx;

                x_scaled = x >> (SHIFT / 2);
                x2 = x_scaled * x_scaled;

                y_scaled = y >> (SHIFT / 2);
                y2 = (y_scaled * y_scaled);

                iter++;
            }

            printf("%c", " .:-;!/>)|&IH%*#"[iter & 0x0F]);
            cx += dx;
        }
        //printf("\n\r");
        cy += dy;
    }
}

int main()
{

    const double xmin_d = -2.09;
    const double xmax_d = 0.7;
    const double ymin_d = -1.2;
    const double ymax_d = 1.2;

    const int32_t xmin = (int32_t)(xmin_d * (1 << SHIFT));
    const int32_t ymin = (int32_t)(ymin_d * (1 << SHIFT));

    const int32_t dx = (int32_t)((xmax_d - xmin_d) / (PIXELS_X - 1) * (1 << SHIFT));
    const int32_t dy = (int32_t)((ymax_d - ymin_d) / (PIXELS_Y - 1) * (1 << SHIFT));

    const int32_t maxiter = 256;

    renderMandel(xmin, dx, ymin, dy, maxiter);

    return (0);
}