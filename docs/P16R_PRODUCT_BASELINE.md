# P16R Product Baseline

This branch uses the reviewed P16R SwiftUI build from Control Center task #121
as the product baseline.

The baseline preserves:

- the dashboard, sidebar, menu bar, and recording HUD;
- the Right Option start/stop interaction and Escape cancellation;
- transcription history and automatic paste behavior;
- the current Mini transcription protocol.

The installed baseline binary used for rollback verification has SHA-256:

```text
1b3bb3326fd15848ed2a174cc779ca88cf8130a66a2f31e4e5ffcddc33183ac2
```

Productization work may replace the external Python runtime and hard-coded
development configuration. It must not replace or redesign the P16R interface.
The public repository and release artifacts are updated only after a clean
install passes the P16R comparison checklist.
