## Bloco 1.2 — close_client() contract

test_that("close_client() is idempotent and sets .closed flag", {
  c1 <- alphainfo_client("ai_test_fake")
  expect_false(isTRUE(c1$.closed))
  c1 <- close_client(c1)
  expect_true(isTRUE(c1$.closed))
  # Double-close must not error
  c1 <- close_client(c1)
  expect_true(isTRUE(c1$.closed))
})

test_that("requests against a closed client raise alphainfo_network_error", {
  c1 <- close_client(alphainfo_client("ai_test_fake"))
  expect_error(
    alphainfo:::build_request(c1, "/v1/version", "GET"),
    regexp = "client is closed"
  )
})
