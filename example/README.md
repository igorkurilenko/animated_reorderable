# Example

This is the example project for the [animated_reorderable](https://pub.dev/packages/animated_reorderable) Flutter package.

## Getting Started

Run the example for a `ListView`:
```
flutter run lib/animated_reorderable_list/animated_reorderable_list.0.dart
```

Run the example for a `GridView`:
```
flutter run lib/animated_reorderable_grid/animated_reorderable_grid.0.dart
```

## Measuring frame times on a device

`integration_test/perf_test.dart` runs the package's moves for real and records how long each frame takes:
- reorders and drags in a list of cards;
- quick removes and swipes;
- reorders between the ends of a list of 1,000;
- a drag across a grid of 12 columns.

Run it in profile mode, which builds the app as a release does:

```
flutter drive --profile --no-dds -d <device id> \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf_test.dart
```

The driver prints the average, 90th and 99th percentile and worst UI-thread (build) and raster time of each scenario. It also prints how many frames went over 8.3 ms (120 Hz) and 16.7 ms (60 Hz). It saves the frame times to `build/perf_run.json`; set `PERF_LABEL` to name the file after the run instead.

- **Find the device id** with `flutter devices`. A simulator can't run profile mode.
- **`-d macos` works too**, but a Mac is faster than most phones, so read it as the best case.
- **Connect an iPhone with a cable.** Over Wi‑Fi, the Mac can find the app but may fail to connect to it. The first launch asks to find devices on the local network: allow it. Keep the phone unlocked while it runs.
- **Keep `--no-dds`.** Without it the app can't connect to its own VM service, which it needs to record frames.
- **Semantics are off**, as for most users, who don't run an assistive technology. Add `--dart-define=SEMANTICS=true` to measure as under a screen reader such as VoiceOver or TalkBack.

