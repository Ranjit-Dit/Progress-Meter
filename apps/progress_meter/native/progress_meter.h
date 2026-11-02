#ifndef PROGRESS_METER_H
#define PROGRESS_METER_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Calculates roadmap readiness from milestone completion fractions.
 *
 * Each item is expected to be between 0.0 and 1.0. Values outside that range
 * are clamped, matching the Flutter benchmark analytics. A negative return
 * value means the input was invalid (a non-finite fraction or a null array
 * with a non-zero count). This function does not judge AI-only dimensions.
 */
double pm_roadmap_readiness_percent(const double *fractions, size_t count);

#ifdef __cplusplus
}
#endif

#endif /* PROGRESS_METER_H */
