# Changelog

## 1.0.0 (2026-11-15)

First public release.

- AC solution from the DC point by Newton's method with step halving.
- Losses shared among generators (by headroom, by PMAX, or at the reference bus).
- Generator reactive limits inside the iteration, including the reference bus.
- Check of bus voltages, branch loadings (MVA, MW or current), generator reactive and active limits, and angle differences.
- A posteriori existence check of the AC solution (Newton-Kantorovich test in rectangular coordinates).
- Repair by successive linear programs with AC verification of every step, a time limit, and a report of the relaxation still needed.
- Marginal loss factors and loss price components at fixed dispatch.
- Batch mode for load levels and for single branch outages.
- Markdown report and graphical interface.
- Regression, robustness and interface tests.
