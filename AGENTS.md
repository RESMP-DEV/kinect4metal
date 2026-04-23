# Kinect4Metal — Repository Guide

## Project Scope

Kinect4Metal is a macOS-only Kinect v2 driver and processing stack designed around Apple-native technologies: Metal compute, VideoToolbox, IOKit, and Swift-friendly integration.

Treat it as an Apple-first driver project, not as a generic cross-platform wrapper.

## Environment and Build

This repo uses CMake and Apple toolchains.

Typical setup from the README:

- install dependencies such as `libusb`, `glfw`, `jpeg-turbo`, `cmake`, and `pkg-config`,
- `cmake -S . -B build -G Xcode` or a normal CMake generator,
- `cmake --build build --config Release`.

The helper `validate_metal_impl.sh` is relevant when changing the Metal path.

## Repository Layout

Important areas:

- `include/` — public headers.
- `src/` — core implementation.
- `platform/` — platform-specific wiring.
- `examples/` — sample apps such as Protonect-style flows.
- `tests/` — validation coverage.
- `tools/` and `scripts/` — operator and helper utilities.
- `doc/` and `METAL_IMPLEMENTATION.md` — architecture references.

## Working Rules

Keep these invariants intact:

- prefer Metal and VideoToolbox paths over legacy compatibility layers,
- maintain the macOS-only posture instead of introducing portability scaffolding,
- preserve clean C++ interfaces for eventual Swift bridging,
- and keep hardware, entitlement, and USB access assumptions explicit in docs and code comments where needed.

If you change the Metal implementation, verify it against the repo’s build and validation path rather than relying on compile-only confidence.

## Validation Expectations

For most changes:

- build the affected targets,
- run the relevant tests,
- and verify example or validation scripts if the touched code affects device IO, decoding, or depth processing.
