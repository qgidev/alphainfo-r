DEFAULT_BASE_URL <- "https://www.alphainfo.io"

#' Create an alphainfo API client
#'
#' @param api_key Your API key. Get one at \url{https://alphainfo.io/register}.
#' @param base_url Override the API base URL (default:
#'   \code{https://www.alphainfo.io}).
#' @param timeout Request timeout in seconds (default: 150).
#'
#' @return An S3 list of class \code{alphainfo_client}.
#' @export
#' @examples
#' \dontrun{
#' client <- alphainfo_client(Sys.getenv("ALPHAINFO_API_KEY"))
#' }
alphainfo_client <- function(api_key, base_url = DEFAULT_BASE_URL, timeout = 150) {
  if (!is.character(api_key) || length(api_key) != 1L || nzchar(api_key) == FALSE) {
    alphainfo_error(
      "alphainfo_validation_error",
      "api_key is required. Get one at https://alphainfo.io/register (format: 'ai_...')"
    )
  }
  structure(
    list(
      api_key  = api_key,
      base_url = sub("/$", "", base_url),
      timeout  = as.numeric(timeout),
      .closed  = FALSE
    ),
    class = "alphainfo_client"
  )
}

#' Close an alphainfo client
#'
#' Marks the client as closed so subsequent calls raise a clear error.
#' The underlying HTTP stack is \code{httr2}, which opens and closes
#' sockets per request — there is no persistent connection pool held
#' by the client object itself, so this is mostly a defensive marker.
#'
#' Safe to call more than once. Use \code{on.exit(close_client(client))}
#' at the top of your function to guarantee cleanup if it errors out.
#'
#' @param client An \code{alphainfo_client}.
#' @return The closed client, invisibly.
#' @export
#' @examples
#' \dontrun{
#' client <- alphainfo_client(Sys.getenv("ALPHAINFO_API_KEY"))
#' on.exit(close_client(client))
#' result <- analyze_signal(client, signal = rnorm(200), sampling_rate = 1000)
#' }
close_client <- function(client) {
  stopifnot(inherits(client, "alphainfo_client"))
  client$.closed <- TRUE
  invisible(client)
}

#' @keywords internal
build_request <- function(client, path, method = "GET", body = NULL) {
  stopifnot(inherits(client, "alphainfo_client"))
  if (isTRUE(client$.closed)) {
    alphainfo_error(
      "alphainfo_network_error",
      "client is closed \u2014 reopen with alphainfo_client()"
    )
  }
  req <- httr2::request(paste0(client$base_url, path)) |>
    httr2::req_headers(
      `X-API-Key` = client$api_key,
      Accept = "application/json",
      `User-Agent` = paste0("alphainfo-r/", SDK_VERSION)
    ) |>
    httr2::req_timeout(client$timeout) |>
    httr2::req_error(is_error = function(resp) FALSE)
  if (method == "POST") {
    req <- req |> httr2::req_body_json(body, auto_unbox = TRUE)
  }
  req
}

#' @keywords internal
perform <- function(req) {
  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) alphainfo_error("alphainfo_network_error", conditionMessage(e))
  )
  body <- httr2::resp_body_string(resp)
  status <- httr2::resp_status(resp)
  if (status >= 400L) {
    map_http_error(resp, body)
  }
  list(body = body, response = resp)
}

#' @keywords internal
parse_json_body <- function(result) {
  jsonlite::fromJSON(result$body, simplifyVector = TRUE, flatten = FALSE)
}

# --------------------------------------------------------------------
# Endpoints
# --------------------------------------------------------------------

#' Analyze a signal
#'
#' @param client An \code{alphainfo_client}.
#' @param signal Numeric vector (min 10 samples).
#' @param sampling_rate Sampling rate in Hz.
#' @param domain Analysis domain (default \code{"generic"}).
#' @param baseline Optional reference signal.
#' @param include_semantic Include the semantic interpretation layer.
#' @param use_multiscale Enable multi-scale analysis (default TRUE server-side).
#' @return A list with structural_score, confidence_band, metrics, etc.
#' @export
analyze_signal <- function(client, signal, sampling_rate, domain = "generic",
                           baseline = NULL, include_semantic = NULL, use_multiscale = NULL) {
  body <- list(
    signal = as.list(as.numeric(signal)),
    sampling_rate = as.numeric(sampling_rate),
    domain = domain
  )
  if (!is.null(baseline)) body$baseline <- as.list(as.numeric(baseline))
  if (!is.null(include_semantic)) body$include_semantic <- isTRUE(include_semantic)
  if (!is.null(use_multiscale)) body$use_multiscale <- isTRUE(use_multiscale)
  parse_json_body(perform(build_request(client, "/v1/analyze/stream", "POST", body)))
}

#' Extract the 5D structural fingerprint of a signal
#'
#' Emits a warning when the signal is shorter than
#' \code{MIN_FINGERPRINT_SAMPLES} (or the with-baseline threshold),
#' because the response will most likely come back with
#' \code{fingerprint_available = FALSE}. Use \code{analyze_signal()}
#' for shorter signals.
#'
#' Returns a list with the expected server fields plus a convenience
#' \code{vector} entry: a numeric vector of length 5 when
#' \code{fingerprint_available} is TRUE, or \code{NULL} otherwise —
#' the package never fills missing dimensions with 0.
#'
#' @inheritParams analyze_signal
#' @export
fingerprint_signal <- function(client, signal, sampling_rate, domain = "generic",
                               baseline = NULL) {
  signal <- as.numeric(signal)
  threshold <- if (!is.null(baseline)) MIN_FINGERPRINT_SAMPLES_WITH_BASELINE else MIN_FINGERPRINT_SAMPLES
  if (length(signal) < threshold) {
    qualifier <- if (!is.null(baseline)) "with baseline" else "without baseline"
    warning(sprintf(
      "Signal has %d samples; the 5D fingerprint needs >=%d %s. Response will likely come back with fingerprint_available=FALSE (reason=\"signal_too_short\"). Use analyze_signal() for shorter signals.",
      length(signal), threshold, qualifier
    ), call. = FALSE)
  }

  body <- list(
    signal = as.list(signal),
    sampling_rate = as.numeric(sampling_rate),
    domain = domain,
    include_semantic = FALSE,
    use_multiscale = FALSE
  )
  if (!is.null(baseline)) body$baseline <- as.list(as.numeric(baseline))
  raw <- parse_json_body(perform(build_request(client, "/v1/analyze/stream", "POST", body)))

  metrics <- raw$metrics %||% list()
  get_sim <- function(name) {
    v <- metrics[[name]]
    if (is.null(v) || is.na(v)) NA_real_ else as.numeric(v)
  }
  sims <- vapply(
    c("sim_local", "sim_spectral", "sim_fractal", "sim_transition", "sim_trend"),
    get_sim, numeric(1)
  )

  if (!is.null(metrics$fingerprint_available)) {
    available <- isTRUE(metrics$fingerprint_available)
    reason <- metrics$fingerprint_reason %||% NA_character_
  } else {
    available <- !anyNA(sims)
    reason <- if (available) NA_character_ else "internal_error"
  }

  vector_value <- if (available) unname(sims) else NULL

  list(
    analysis_id = raw$analysis_id,
    structural_score = raw$structural_score,
    confidence_band = raw$confidence_band,
    sim_local = sims[["sim_local"]],
    sim_spectral = sims[["sim_spectral"]],
    sim_fractal = sims[["sim_fractal"]],
    sim_transition = sims[["sim_transition"]],
    sim_trend = sims[["sim_trend"]],
    fingerprint_available = available,
    fingerprint_reason = reason,
    vector = vector_value
  )
}

# Simple null-coalesce for older R.
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Analyze multiple signals in one request
#' @export
analyze_batch <- function(client, signals, sampling_rate, domain = "generic",
                          baselines = NULL, include_semantic = NULL, use_multiscale = NULL) {
  body <- list(
    signals = lapply(signals, as.list),
    sampling_rate = as.numeric(sampling_rate),
    domain = domain
  )
  if (!is.null(baselines)) body$baselines <- lapply(baselines, function(b) if (is.null(b)) NULL else as.list(b))
  if (!is.null(include_semantic)) body$include_semantic <- isTRUE(include_semantic)
  if (!is.null(use_multiscale)) body$use_multiscale <- isTRUE(use_multiscale)
  parse_json_body(perform(build_request(client, "/v1/analyze/batch", "POST", body)))
}

#' Pairwise similarity matrix
#' @export
analyze_matrix <- function(client, signals, sampling_rate, domain = "generic",
                           use_multiscale = NULL) {
  body <- list(
    signals = lapply(signals, as.list),
    sampling_rate = as.numeric(sampling_rate),
    domain = domain
  )
  if (!is.null(use_multiscale)) body$use_multiscale <- isTRUE(use_multiscale)
  parse_json_body(perform(build_request(client, "/v1/analyze/matrix", "POST", body)))
}

#' Multi-channel (vector) analysis
#' @export
analyze_vector <- function(client, channels, sampling_rate, domain = "generic",
                           baselines = NULL, include_semantic = NULL, use_multiscale = NULL) {
  body <- list(
    channels = lapply(channels, as.list),
    sampling_rate = as.numeric(sampling_rate),
    domain = domain
  )
  if (!is.null(baselines)) body$baselines <- lapply(baselines, as.list)
  if (!is.null(include_semantic)) body$include_semantic <- isTRUE(include_semantic)
  if (!is.null(use_multiscale)) body$use_multiscale <- isTRUE(use_multiscale)
  parse_json_body(perform(build_request(client, "/v1/analyze/vector", "POST", body)))
}

#' List recent analyses in the audit trail
#' @export
audit_list <- function(client, limit = 100L) {
  parse_json_body(perform(build_request(client, paste0("/v1/audit/list?limit=", as.integer(limit)), "GET")))
}

#' Replay a past analysis by UUID
#' @export
audit_replay <- function(client, analysis_id) {
  if (!is.character(analysis_id) || !nzchar(analysis_id)) {
    alphainfo_error("alphainfo_validation_error", "analysis_id cannot be empty")
  }
  parse_json_body(perform(build_request(
    client, paste0("/v1/audit/replay/", utils::URLencode(analysis_id, reserved = TRUE)), "GET"
  )))
}

# --------------------------------------------------------------------
# No-auth helpers
# --------------------------------------------------------------------

#' Fetch the public encoding guide (no API key needed)
#' @param base_url Override the base URL (default: production).
#' @export
alphainfo_guide <- function(base_url = DEFAULT_BASE_URL) {
  fetch_noauth(paste0(sub("/$", "", base_url), "/v1/guide"))
}

#' Fetch the API health status (no API key needed)
#' @inheritParams alphainfo_guide
#' @export
alphainfo_health <- function(base_url = DEFAULT_BASE_URL) {
  fetch_noauth(paste0(sub("/$", "", base_url), "/health"))
}

#' List available billing plans
#' @param client An \code{alphainfo_client}.
#' @export
alphainfo_plans <- function(client) {
  parse_json_body(perform(build_request(client, "/api/plans", "GET")))
}

#' @keywords internal
fetch_noauth <- function(url) {
  req <- httr2::request(url) |>
    httr2::req_headers(
      Accept = "application/json",
      `User-Agent` = paste0("alphainfo-r/", SDK_VERSION)
    ) |>
    httr2::req_timeout(30) |>
    httr2::req_error(is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req),
                   error = function(e) alphainfo_error("alphainfo_network_error", conditionMessage(e)))
  body <- httr2::resp_body_string(resp)
  status <- httr2::resp_status(resp)
  if (status >= 400L) map_http_error(resp, body)
  jsonlite::fromJSON(body, simplifyVector = TRUE)
}
