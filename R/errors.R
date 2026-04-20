#' @keywords internal
alphainfo_error <- function(class, message, status_code = NULL, response_data = NULL, ...) {
  rlang::abort(
    message = message,
    class = c(class, "alphainfo_error"),
    status_code = status_code,
    response_data = response_data,
    ...
  )
}

#' @keywords internal
map_http_error <- function(response, body_text) {
  status <- httr2::resp_status(response)

  parsed <- tryCatch(
    jsonlite::fromJSON(body_text, simplifyVector = FALSE),
    error = function(e) list()
  )
  detail <- parsed$detail
  if (is.list(detail) && !is.null(detail$message)) {
    message <- detail$message
  } else if (is.character(detail)) {
    message <- detail
  } else {
    message <- paste0("HTTP ", status)
  }

  if (status == 401L) {
    alphainfo_error(
      "alphainfo_auth_error",
      paste0(
        "Invalid or missing API key. Get a free key at ",
        "https://alphainfo.io/register and pass it to alphainfo_client()."
      ),
      status_code = status, response_data = parsed
    )
  } else if (status %in% c(400L, 413L, 422L)) {
    alphainfo_error("alphainfo_validation_error", message, status_code = status, response_data = parsed)
  } else if (status == 404L) {
    alphainfo_error("alphainfo_not_found", message, status_code = status, response_data = parsed)
  } else if (status == 429L) {
    retry_after <- suppressWarnings(as.integer(httr2::resp_header(response, "Retry-After")))
    if (is.na(retry_after)) retry_after <- 0L
    alphainfo_error(
      "alphainfo_rate_limit_error",
      message,
      status_code = status, response_data = parsed,
      retry_after = retry_after
    )
  } else if (status >= 500L) {
    alphainfo_error("alphainfo_api_error", paste("Server error:", message),
                    status_code = status, response_data = parsed)
  } else {
    alphainfo_error("alphainfo_api_error", message, status_code = status, response_data = parsed)
  }
}
