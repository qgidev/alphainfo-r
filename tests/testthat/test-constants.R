test_that("public constants match the documented server thresholds", {
  expect_equal(MIN_FINGERPRINT_SAMPLES, 192L)
  expect_equal(MIN_FINGERPRINT_SAMPLES_WITH_BASELINE, 50L)
  expect_gt(MIN_FINGERPRINT_SAMPLES, MIN_FINGERPRINT_SAMPLES_WITH_BASELINE)
})

test_that("alphainfo_client requires an API key", {
  expect_error(alphainfo_client(""), "alphainfo.io/register")
  expect_error(alphainfo_client(NULL), "api_key is required")
})

test_that("fingerprint_signal warns for short signals", {
  client <- alphainfo_client("ai_test", base_url = "http://127.0.0.1:1")
  expect_warning(
    # httr2 will fail to connect — we catch that separately; we only
    # care that the warn() fires before the request is attempted.
    tryCatch(
      fingerprint_signal(client, signal = rep(0, 50), sampling_rate = 1),
      error = function(e) NULL
    ),
    regexp = "fingerprint_available=FALSE"
  )
})
