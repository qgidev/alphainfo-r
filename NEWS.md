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
