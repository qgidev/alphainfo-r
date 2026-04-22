# alphainfo 1.5.14

Version parity bump. No functional change. Bumped to stay aligned with
the Python SDK 1.5.14 release (a cosmetic `__version__` attribute fix
specific to Python). Behaviour is identical to 1.5.13.


Response contract refinement and documentation improvements.

Server response shape has been neutralised — the following keys have new names:

* `metrics$scale_entropy`                            → `metrics$complexity_index`
* `metrics$multiscale$curvature`                     → `metrics$multiscale$scale_profile`
* `metrics$multiscale$summary$scale_curvature_score` → `metrics$multiscale$summary$profile_score`

The 5D fingerprint contract is unchanged.


Added automatic domain inference; `domain` now optional with sensible
default.

* `analyze_signal()` — `domain` argument documented as optional.
  Pass `"auto"` to have the server infer the calibration from the
  signal. The returned list now always contains `domain_applied`
  (server 1.5.12+); when `domain = "auto"` it also contains
  `domain_inference` with `inferred`, `confidence`, `fallback_used`
  and `reasoning`.
* New exported helper `analyze_auto()` — syntactic sugar for
  `analyze_signal(..., domain = "auto")`.
* Roxygen comments updated to explain aliases (`"fintech"` →
  `"finance"`, `"biomed"` → `"biomedical"`, ...) and the server's
  "Did you mean ...?" suggestion for typos.

Backwards-compatible.

# alphainfo 1.5.11

Connection cleanup improvements.

* New `close_client()` — marks a client as closed so subsequent calls
  raise a clear error instead of silently succeeding. The R SDK uses
  `httr2` (no persistent per-client connection pool), so this is
  mostly a defensive marker, but it lets users write the idiomatic
  `on.exit(close_client(client))` pattern at the top of functions.

# alphainfo 1.5.10

Initial release — parity with Python SDK 1.5.10.

* `alphainfo_client()` factory + `analyze_signal()`, `fingerprint_signal()`,
  `analyze_batch()`, `analyze_matrix()`, `analyze_vector()`,
  `audit_list()`, `audit_replay()`.
* `alphainfo_guide()` and `alphainfo_health()` work without an API key.
* Public constants `MIN_FINGERPRINT_SAMPLES` (192) and
  `MIN_FINGERPRINT_SAMPLES_WITH_BASELINE` (50).
* Honest fingerprint contract — `fingerprint_signal()` returns `NA`
  for each dimension the engine could not compute and a `NULL` `vector`,
  never silent zeros.
* Classed errors (`alphainfo_auth_error`, `alphainfo_rate_limit_error`,
  `alphainfo_validation_error`, `alphainfo_not_found`, `alphainfo_api_error`,
  `alphainfo_network_error`) for `tryCatch`.
* `warning()` when `fingerprint_signal()` is called with a signal shorter
  than the threshold.
