# alphainfo (R)

[![CRAN](https://img.shields.io/cran/v/alphainfo.svg)](https://cran.r-project.org/package=alphainfo)
[![R-CMD-check](https://github.com/qgidev/alphainfo-r/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/qgidev/alphainfo-r/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

R client for the [alphainfo.io](https://alphainfo.io) Structural Intelligence API.

## Install

Before CRAN:

```r
# From GitHub
install.packages("remotes")
remotes::install_github("qgidev/alphainfo-r")
```

After CRAN:

```r
install.packages("alphainfo")
```

## 30-second try

**Step 1 — [get a free API key](https://alphainfo.io/register)**.

**Step 2**:

```r
library(alphainfo)

client <- alphainfo_client(Sys.getenv("ALPHAINFO_API_KEY"))

# Any time series — here, a toy sine with a regime change
signal <- c(sin(seq(0, 20, length.out = 200)),
            sin(seq(0, 20, length.out = 200)) * 3)

result <- analyze_signal(client, signal = signal, sampling_rate = 100)
result$confidence_band   # "stable" | "transition" | "unstable"
result$structural_score  # 0 (changed) → 1 (preserved)
result$analysis_id       # UUID for audit replay
```

## Structural fingerprint

```r
fp <- fingerprint_signal(client, signal = signal, sampling_rate = 250)

if (isTRUE(fp$fingerprint_available)) {
  fp$vector   # length-5 numeric vector for ANN / similarity search
} else {
  message("unavailable: ", fp$fingerprint_reason)
}
```

**Minimum signal length:**

| Case | Minimum samples | Constant |
|---|---|---|
| No baseline | 192 | `MIN_FINGERPRINT_SAMPLES` |
| With baseline | 50 | `MIN_FINGERPRINT_SAMPLES_WITH_BASELINE` |

Below the threshold, `fp$vector` is `NULL` (never filled with zeros) and the package emits a `warning()` at call time so you can fall back to `analyze_signal()`.

## Error handling

Errors inherit from `alphainfo_error`. Use `tryCatch` with specific classes:

```r
tryCatch(
  analyze_signal(client, signal, sampling_rate = 1),
  alphainfo_auth_error       = function(e) message("get a key at alphainfo.io/register"),
  alphainfo_rate_limit_error = function(e) Sys.sleep(attr(e, "retry_after", exact = TRUE)),
  alphainfo_validation_error = function(e) stop("bad input: ", conditionMessage(e)),
  alphainfo_not_found        = function(e) NULL,
  alphainfo_api_error        = function(e) stop(e),
  alphainfo_network_error    = function(e) stop(e)
)
```

## Zero-auth exploration

```r
alphainfo_guide()
alphainfo_health()
```

## Links

- [Web](https://alphainfo.io)
- [Python SDK](https://pypi.org/project/alphainfo/)
- [JS/TS SDK](https://www.npmjs.com/package/alphainfo)
- [Encoding guide](https://www.alphainfo.io/v1/guide)

## About

Built by **QGI Quantum Systems LTDA** — São Paulo, Brazil.
Contact: contato@alphainfo.io · api@alphainfo.io

## License

MIT
