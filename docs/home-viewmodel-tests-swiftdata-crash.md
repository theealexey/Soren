# HomeViewModelTests crash with SwiftData SDRecurringItem in in-memory test container

**Status:** Open
**Date:** 2026-06-12

## Summary

HomeViewModelTests currently crash with SIGILL inside SwiftData when
`SwiftDataRecurringItemRepository.save(_:)` inserts `SDRecurringItem` into an
in-memory ModelContainer. The crash appears unrelated to Home UI, AmountLabel,
screenshot polish, or production runtime behavior.

## Important

- Do not add warm-up hacks.
- Do not use `MainActor.assumeIsolated`.
- Do not modify production repository code as a workaround.
- Do not keep diagnostic suites.
- Do not re-run long test loops.

## Likely future direction

Refactor HomeViewModelTests to use a fake/in-memory repository or fake use
cases instead of SwiftData. Keep SwiftData repository behavior covered by
smaller dedicated integration tests.
