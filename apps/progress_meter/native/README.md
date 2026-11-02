# Native C progress helper

This small C module mirrors the app’s deterministic benchmark calculation:
roadmap readiness is the average of each milestone’s completion fraction,
expressed as a percentage. Assessment marks and the four AI-only dimensions
remain owned by the Flutter/domain layer; this helper never invents or judges
those values.

The public header uses a stable C ABI so it can be called later from Dart FFI,
an iOS/macOS plugin, or another client without changing the calculation.

Run its standalone smoke test from this directory:

```sh
make test
make clean
```

The test binary and object files are ignored and are never committed. The
current Flutter build still uses the Dart implementation directly; wiring the
same function into platform libraries can be added when native acceleration is
needed.
