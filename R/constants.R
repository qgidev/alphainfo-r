#' Minimum signal length for a full 5D fingerprint
#'
#' The alphainfo engine needs at least \code{MIN_FINGERPRINT_SAMPLES}
#' samples when no baseline is provided. Below this threshold the
#' server returns \code{fingerprint_available = FALSE} with
#' \code{fingerprint_reason = "signal_too_short"}. With a baseline of
#' comparable length, signals as short as
#' \code{MIN_FINGERPRINT_SAMPLES_WITH_BASELINE} samples can still
#' produce a full fingerprint.
#'
#' Values are kept in sync with the server's
#' \code{signal_requirements.fingerprint_minimum_samples} field in
#' \code{/v1/guide}.
#'
#' @export
MIN_FINGERPRINT_SAMPLES <- 192L

#' @rdname MIN_FINGERPRINT_SAMPLES
#' @export
MIN_FINGERPRINT_SAMPLES_WITH_BASELINE <- 50L

#' @keywords internal
SDK_VERSION <- "1.5.19"
