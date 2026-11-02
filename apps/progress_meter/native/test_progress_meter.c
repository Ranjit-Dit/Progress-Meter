#include "progress_meter.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

static void test_readiness_average_and_clamping(void) {
  const double milestones[] = {1.0, 0.75, 0.0, 1.25};
  const double readiness =
      pm_roadmap_readiness_percent(milestones, sizeof(milestones) / sizeof(*milestones));
  assert(fabs(readiness - 68.75) < 0.000001);
}

static void test_empty_roadmap(void) {
  assert(pm_roadmap_readiness_percent(NULL, 0) == 0.0);
}

static void test_invalid_input(void) {
  const double invalid[] = {0.5, NAN};
  assert(pm_roadmap_readiness_percent(NULL, 1) < 0.0);
  assert(pm_roadmap_readiness_percent(invalid, 2) < 0.0);
}

int main(void) {
  test_readiness_average_and_clamping();
  test_empty_roadmap();
  test_invalid_input();
  puts("Progress Meter C tests passed.");
  return 0;
}
