#include "progress_meter.h"

#include <math.h>

double pm_roadmap_readiness_percent(const double *fractions, size_t count) {
  if (count == 0) {
    return 0.0;
  }
  if (fractions == NULL) {
    return -1.0;
  }

  double total = 0.0;
  for (size_t i = 0; i < count; ++i) {
    const double fraction = fractions[i];
    if (!isfinite(fraction)) {
      return -1.0;
    }

    double clamped = fraction;
    if (clamped < 0.0) {
      clamped = 0.0;
    } else if (clamped > 1.0) {
      clamped = 1.0;
    }
    total += clamped;
  }

  return (total * 100.0) / (double)count;
}
