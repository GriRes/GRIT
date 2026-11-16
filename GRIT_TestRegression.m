function ok = GRIT_TestRegression(big)
%GRIT_TESTREGRESSION  Numerical regression tests of GRIT.
%   OK = GRIT_TESTREGRESSION() runs the tests on small and medium cases.
%   OK = GRIT_TESTREGRESSION(true) adds the time comparison with AC-OPF on
%   case1354pegase and case3120sp.
%
% ************************************************************
%    GRIT(TM) - Grid Realizability Inspection Tool
%    AC Feasibility Check and Repair of DC Dispatch
%    Version 1.0.0 (2026)
%
%    A tool of the GriRes(TM) Suite
%    (Grid Resilience Suite)
%
% Copyright (c) 2026 Francis Yunhe Hou
% SPDX-License-Identifier: GPL-3.0-or-later
%
% Author:   Dr. Francis Yunhe Hou
% Contact:  fyhou@vt.edu, yunhe.hou@gmail.com
% Profile:  https://ece.vt.edu/people/profile/francis-hou.html
% Homepage: https://francisyhou.github.io
% Website:  https://github.com/GriRes/GRIT
%
% This program is free software: you can redistribute it and/or
% modify it under the terms of the GNU General Public License as
% published by the Free Software Foundation, either version 3 of
% the License, or (at your option) any later version. It is
% distributed WITHOUT ANY WARRANTY. See the file LICENSE.
% A commercial license is available for uses where the GPL terms
% cannot be met. Contact the author.
%
% Portions of this software were developed with the assistance of
% Claude, an AI system made by Anthropic. All AI-generated code has
% been reviewed, tested, and validated by the author. The author
% assumes full responsibility for the correctness and quality of the
% final code.
% ************************************************************
if nargin < 1, big = false; end
[PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM] = idx_bus; %#ok<ASGLU>
PF = 14; QF = 15; BR_STATUS = 11;
T = struct('n', 0, 'fail', 0);
mpo = mpoption('verbose', 0, 'out.all', 0);
small = {'case9', 'case14', 'case30', 'case39', 'case57', 'case118', 'case300'};

% 1. agreement with the AC power flow of MATPOWER (losses at the reference bus, no reactive limits)
for c = 1:numel(small)
    R = GRIT_Run(small{c}, 'verbose', 0, 'slack.mode', 'single', 'newton.enforce_q', false, 'price.enable', false);
    r = runpf(R.model.mpc, mpo);
    d = max(abs([r.branch(R.ac.branch(:, 1), PF) - R.ac.branch(:, 4); r.branch(R.ac.branch(:, 1), QF) - R.ac.branch(:, 5)]));
    T = check(T, r.success && d < 1e-4, sprintf('%s: flows agree with MATPOWER (largest difference %.1e)', small{c}, d));
end
% 2. power balance and generator limit logic in the default mode
for c = 1:numel(small)
    R = GRIT_Run(small{c}, 'verbose', 0, 'cert.mode', 'exact');
    M = R.model; S = R.solution; V = S.V;
    Sc = V .* conj(M.Ybus * V);
    Pinj = M.Cg * (R.check.Pg / M.baseMVA) - M.Pd;
    resP = max(abs(real(Sc) - Pinj));
    Qg = imag(Sc) + M.Qd; Vm = abs(V); g = find(M.isgen);
    good = (S.atlim(g) == 0 & abs(Vm(g) - M.Vset(g)) < 1e-7 & Qg(g) <= M.bqmax(g) + 1e-5 & Qg(g) >= M.bqmin(g) - 1e-5) | ...
           (S.atlim(g) > 0 & abs(Qg(g) - M.bqmax(g)) < 1e-6) | (S.atlim(g) < 0 & abs(Qg(g) - M.bqmin(g)) < 1e-6);
    resQ = max(abs(Qg(~M.isgen)));
    T = check(T, resP < 1e-6 && resQ < 1e-6, sprintf('%s: active and reactive balance (%.1e, %.1e pu)', small{c}, resP, resQ));
    T = check(T, nnz(~good) <= R.check.n_unresolved, sprintf('%s: every generator bus holds its set point or sits on a reactive limit', small{c}));
    T = check(T, R.cert.certified && R.cert.h < 0.5, sprintf('%s: existence check passes (h = %.1e)', small{c}, R.cert.h));
    o2 = R.opts; o2.cert.mode = 'estimate';
    N = S; N.Sbus = M.Sbus; N.ref = M.ref; 
    up = find(S.atlim > 0); dn = find(S.atlim < 0);
    N.Sbus(up) = real(N.Sbus(up)) + 1j * (M.bqmax(up) - M.Qd(up)); N.Sbus(dn) = real(N.Sbus(dn)) + 1j * (M.bqmin(dn) - M.Qd(dn));
    C2 = GRIT_Certificate(M, N, o2);
    T = check(T, abs(C2.omega - R.cert.omega) <= 0.1 * R.cert.omega, sprintf('%s: estimated constant within 10 percent of the exact one', small{c}));
end
% 3. sensitivities against finite differences
for c = {'case30', 'case118'}
    o = GRIT_Config('verbose', 0, 'newton.enforce_q', false, 'newton.tol', 1e-11);
    M = GRIT_Model(c{1}, o); N = GRIT_Newton(M, o);
    q = struct('vbus', N.pq(1:3), 'branch', (1:3)', 'qbus', [M.ref; N.pv(1)], 'loss', true);
    S = GRIT_Sensitivity(M, N, q, o); hh = 1e-5; e = 0;
    for b = [N.pq(2), N.pv(2)]
        st = struct('V', N.V, 's', N.s, 'Sbus', M.Sbus); st.Sbus(b) = st.Sbus(b) + hh; N1 = GRIT_Newton(M, o, st);
        st.Sbus(b) = st.Sbus(b) - 2 * hh; N2 = GRIT_Newton(M, o, st);
        e = max(e, max(abs((yv(M, N1, q) - yv(M, N2, q)) / (2 * hh) - S.GP(:, b))));
    end
    for b = [M.ref, N.pv(3)]
        st = struct('V', N.V, 's', N.s, 'Vset', M.Vset); st.Vset(b) = st.Vset(b) + hh; N1 = GRIT_Newton(M, o, st);
        st.Vset(b) = st.Vset(b) - 2 * hh; N2 = GRIT_Newton(M, o, st);
        e = max(e, max(abs((yv(M, N1, q) - yv(M, N2, q)) / (2 * hh) - S.GV(:, b))));
    end
    T = check(T, e < 1e-5, sprintf('%s: sensitivities agree with finite differences (%.1e)', c{1}, e));
    Pr = GRIT_Price(M, N, o);
    T = check(T, abs(sum(M.abus .* Pr.itl)) < 1e-10, sprintf('%s: loss factors weighted by the sharing factors sum to zero', c{1}));
end
% 4. repair
for c = {'case14', 'case30', 'case39', 'case57'}
    R = GRIT_Run(c{1}, 'verbose', 0, 'repair.enable', true);
    okc = strcmp(R.verdict, 'REPAIRED') && R.check.n_viol == 0;
    if okc
        M = R.model; V = R.solution.V; Sc = V .* conj(M.Ybus * V);
        okc = max(abs(real(Sc) - (M.Cg * (R.check.Pg / M.baseMVA) - M.Pd))) < 1e-6 && all(abs(V) >= M.vmin - 1e-5) && all(abs(V) <= M.vmax + 1e-5);
    end
    T = check(T, okc, sprintf('%s: repair succeeds and the repaired point satisfies balance and voltage limits', c{1}));
end
R = GRIT_Run('case300', 'verbose', 0, 'repair.enable', true, 'relax.v', 0.01, 'relax.flow_pct', 2);
T = check(T, any(strcmp(R.verdict, {'REPAIRED', 'RELAXED'})), sprintf('case300: repair with relaxation ends as %s', R.verdict));
% 5. no AC solution
R = GRIT_Run('case118', 'verbose', 0, 'dispatch.source', 'case', 'dispatch.load_scale', 3.2);
T = check(T, strcmp(R.verdict, 'NO_SOLUTION') && R.newton.reach < 1, 'case118 at 3.2 times the load: no AC solution is reported');
% 6. binding DC limits and price information
nb = 0; sc = NaN; R = [];
for sc = [0.95 0.9 0.85 0.8 0.75]
    try
        R = GRIT_Run('case30', 'verbose', 0, 'limits.rate_scale', sc);
    catch
        continue;
    end
    if ~isempty(R.price), nb = size(R.price.binding, 1); end
    if nb > 0, break; end
end
T = check(T, nb > 0 && all(isfinite(R.price.cong_delta)) && all(isfinite(R.price.binding(:))), ...
    sprintf('case30 with ratings at %.0f percent: %d binding DC limits, sensitivity comparison is finite', 100 * sc, nb));
% 7. reactive load uncertainty
R = GRIT_Run('case57', 'verbose', 0, 'q_margin', 0.1);
T = check(T, isfield(R.check, 'n_band') && R.check.n_band >= 0, 'case57: reactive load uncertainty band is computed');
% 8. batch
B = GRIT_Batch('case118', 'load', [0.7 1.0 1.2], 'verbose', 0);
T = check(T, size(B.table, 1) == 3 && all(B.table(:, 2) <= 5), 'case118: load batch returns three scenarios');
o = GRIT_Config('verbose', 0, 'slack.mode', 'single', 'newton.enforce_q', false);
B = GRIT_Batch('case118', 'n-1', [3 40 90 150], o);
M = GRIT_Model('case118', o); e = 0;
for l = [3 40 90 150]
    m = M.mpc; m.branch(l, BR_STATUS) = 0; r = runpf(m, mpo);
    e = max(e, abs(min(r.bus(:, VM)) - B.table(B.table(:, 1) == l, 4)));
end
T = check(T, e < 1e-6, sprintf('case118: N-1 voltages agree with MATPOWER (%.1e)', e));
B = GRIT_Batch('case30', 'n-1', [], 'verbose', 0);
T = check(T, sum(B.count) == size(B.table, 1) && B.count(6) > 0, 'case30: N-1 batch of all branches, islanding outages are flagged');
% 9. report
f = [tempname '.md']; R = GRIT_Run('case30', 'verbose', 0, 'repair.enable', true); GRIT_Report(R, f);
d = dir(f); T = check(T, ~isempty(d) && d.bytes > 500, 'case30: report file is written'); delete(f);
% 10. time against AC-OPF
if big
    for c = {'case1354pegase', 'case3120sp'}
        R = GRIT_Run(c{1}, 'verbose', 0, 'compare.opf', true);
        T = check(T, R.time.total < R.compare.opf_time, sprintf('%s: check takes %.2f s, AC-OPF takes %.2f s', c{1}, R.time.total, R.compare.opf_time));
    end
end
fprintf('GRIT regression: %d of %d tests passed.\n', T.n - T.fail, T.n);
ok = T.fail == 0;
end

function T = check(T, cond, msg)
T.n = T.n + 1;
if cond, fprintf('  pass  %s\n', msg); else, T.fail = T.fail + 1; fprintf('  FAIL  %s\n', msg); end
end

function y = yv(M, N, q)
V = N.V; br = q.branch;
Sf = V(M.fbus(br)) .* conj(M.Yf(br, :) * V); St = V(M.tbus(br)) .* conj(M.Yt(br, :) * V);
Sc = V(q.qbus) .* conj(M.Ybus(q.qbus, :) * V);
y = [abs(V(q.vbus)); max(abs(Sf), abs(St)); imag(Sc) + M.Qd(q.qbus); N.s];
end
