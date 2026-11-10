# Initializr hydration triage (M0.7.1)

The M0.7 desktop apps are unaffected. `tsc --noEmit` and `vite build` do
not verify that a browser successfully hydrates the server HTML.

1. Apply the hotfix to M0.7 and run `just initializr` in a fresh tab.
2. If the error remains, run `just initializr-csr`. This disables HTML SSR
   **for diagnosis**, not for deployment. The Node API and Python bridge remain.
3. Compare clean-session results, disable browser extensions, and check the
   first browser console exception before the hydration mismatch.
4. Re-enable SSR for the product once a browser test covers the initial route.

The Icon component now constructs only the selected JSX branch. This is a
candidate cause, **not** a proven root cause in the user's browser.

A proper CI gate should load `/` with a real browser, wait for the catalog,
assert that the addon list is interactive, and fail on any pageerror or hydration
mismatch. Test both dev mode and production preview; do not substitute a static
source-code test for this runtime check.
