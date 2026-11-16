# GRIT™: Grid Realizability Inspection Tool

**AC Feasibility Check and Repair of DC Dispatch.** Version 1.0.0. A tool of the GriRes™ Suite (Grid Resilience Suite).

Market clearing and operational planning use the DC model. The DC model has no voltage magnitudes, no reactive power and no losses. GRIT takes a DC dispatch and answers three questions.

1. Does the dispatch have an AC power flow solution?
2. Does the AC solution satisfy the operating limits (bus voltages, branch loadings, generator reactive and active limits)?
3. If not, which nearby dispatch does?

The computing time of a check is a small fraction of the time of one AC-OPF.

## Requirements

- MATLAB R2020b or later (tested with R2026a), or GNU Octave 8.
- MATPOWER 7.1 or later (tested with 8.1).
- Optimization Toolbox (linprog) is recommended for the repair. Without it GRIT uses the solvers that ship with MATPOWER, which are slower.

## Quick start

```matlab
addpath('path/to/GRIT');
R = GRIT_Run('case118');                          % check
R = GRIT_Run('case30', 'repair.enable', true);    % check and repair
GRIT_Report(R);                                   % Markdown report
GRIT_Launch                                       % graphical interface
```

## What a run does

1. **DC dispatch.** GRIT runs the DC-OPF of MATPOWER, or takes the active power values of the case.
2. **AC solution.** Newton's method starts from the DC point. The generators share the losses. A generator that reaches a reactive limit releases its voltage set point.
3. **Check.** Every limit is evaluated at the AC solution. The result lists each violation with its value, limit and excess.
4. **Existence check.** A Newton-Kantorovich test at the computed point confirms that an exact AC solution lies within a small distance of it.
5. **Repair (optional).** Successive linear programs move generator active power and voltage set points by the smallest amount. Each step is verified by a new AC solution.
6. **Loss factors.** Marginal loss factors at the fixed dispatch.

## Verdicts

| Verdict | Meaning |
|---|---|
| `FEASIBLE` | An AC solution exists and all checked limits hold. |
| `VIOLATED` | An AC solution exists and at least one limit is violated. |
| `REPAIRED` | The repair found a nearby dispatch that satisfies all limits. |
| `RELAXED` | The repair left violations inside the relaxation set by the user. |
| `NO_SOLUTION` | No AC solution was found. This is not a proof that none exists. |

## Main functions

| Function | Purpose |
|---|---|
| `GRIT_Run` | Check one case. |
| `GRIT_Batch` | Check many load levels, or all single branch outages (N-1). |
| `GRIT_Report` | Write a Markdown report. |
| `GRIT_GUI`, `GRIT_Launch` | Graphical interface. |
| `GRIT_Config` | Options with their defaults. |
| `GRIT_TestSuite` | Regression, robustness and interface tests. |

## Limitations of Version 1.0.0

- One connected network with one reference bus.
- The repair moves generator active power and voltage set points. It has no shunt, tap or load-shedding controls. Wide-area low voltage that needs reactive compensation is reported, not repaired.
- The repair finds a feasible dispatch near the DC dispatch. It does not minimize cost. Use an AC-OPF for the optimal AC dispatch.
- The loss factors hold for the fixed dispatch. They are not AC-OPF prices.
- `NO_SOLUTION` means that Newton's method and a continuation found no solution. It is not a proof.
- The existence check uses floating-point arithmetic without rounding control. On large systems the constant of the test is an estimate.
- DC lines of a MATPOWER case are not modeled.

## Documentation

See `Doc/GRIT_Manual_v1.0.0.pdf`.

## License

GPL-3.0-or-later. A commercial license is available for uses where the GPL terms cannot be met. See `LICENSE` and `NOTICE`.

## Author

Dr. Francis Yunhe Hou, Virginia Tech. Contact: fyhou@vt.edu, yunhe.hou@gmail.com. Profile: https://ece.vt.edu/people/profile/francis-hou.html. Homepage: https://francisyhou.github.io.

Portions of this software were developed with the assistance of Claude, an AI system made by Anthropic. All AI-generated code has been reviewed, tested, and validated by the author.
