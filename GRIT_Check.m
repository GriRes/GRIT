function K = GRIT_Check(M, N, opts)
%GRIT_CHECK  Check the operating limits at an AC solution.
%   K = GRIT_CHECK(M, N, OPTS) evaluates bus voltage magnitudes, branch
%   loadings at both ends, generator reactive power, generator active
%   power after the losses are shared, and (optional) branch angle
%   differences. K.viol lists every violated limit, one row each:
%   [kind, internal index, value, limit, excess]. K.kind_names names the
%   kinds. Units: pu for voltage, MVA or MW for branches, Mvar, MW, degree.
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

base = M.baseMVA; V = N.V; nb = M.nb;
Vm = abs(V); Va = angle(V);
Sf = V(M.fbus) .* conj(M.Yf * V);
St = V(M.tbus) .* conj(M.Yt * V);
Scal = V .* conj(M.Ybus * V);

% ---- voltage
K.Vm = Vm; K.Va = Va * 180 / pi;
K.margin_v = min(Vm - M.vmin, M.vmax - Vm);                   % pu, negative when violated

% ---- branch loading
switch upper(opts.limits.flow)
    case 'S'
        lf = abs(Sf); lt = abs(St); K.flow_unit = 'MVA';
    case 'P'
        lf = abs(real(Sf)); lt = abs(real(St)); K.flow_unit = 'MW';
    case 'I'
        lf = abs(M.Yf * V); lt = abs(M.Yt * V); K.flow_unit = 'MVA at 1 pu';
    otherwise
        error('GRIT:input', 'Option limits.flow must be ''S'', ''P'' or ''I''.');
end
K.Sf = Sf * base; K.St = St * base;
K.loading = max(lf, lt) * base;                               % MVA or MW
K.rate = M.rate * base;                                       % 0 means no limit
has = M.rate > 0;
K.margin_flow = inf(M.nl, 1);
K.margin_flow(has) = K.rate(has) - K.loading(has);
K.loading_pct = nan(M.nl, 1);
K.loading_pct(has) = 100 * K.loading(has) ./ K.rate(has);

% ---- generators
Qgb = imag(Scal) + M.Qd;                                      % reactive output by bus (pu)
Qgb(~M.isgen) = 0;
K.Qg_bus = Qgb * base;
K.Qg = localSplit(M, Qgb) * base;                             % by generator (Mvar)
K.Pg = (M.Pg + M.alpha * N.s) * base;                         % by generator (MW), losses shared
K.Pg_dc = M.Pg * base;
K.loss = N.s * base;
K.margin_qmax = (M.bqmax - Qgb) * base; K.margin_qmax(~M.isgen) = Inf;
K.margin_qmin = (Qgb - M.bqmin) * base; K.margin_qmin(~M.isgen) = Inf;
K.margin_pmax = M.gpmax * base - K.Pg;
K.margin_pmin = K.Pg - M.gpmin * base;

% ---- angle differences
dth = (Va(M.fbus) - Va(M.tbus)) * 180 / pi;
K.angle_diff = dth;

% ---- list of violations
viol = zeros(0, 5);
i = find(Vm < M.vmin - opts.tol.v);   viol = [viol; 1*ones(numel(i),1), i, Vm(i), M.vmin(i), M.vmin(i) - Vm(i)];
i = find(Vm > M.vmax + opts.tol.v);   viol = [viol; 2*ones(numel(i),1), i, Vm(i), M.vmax(i), Vm(i) - M.vmax(i)];
i = find(K.margin_flow < -opts.tol.flow);
viol = [viol; 3*ones(numel(i),1), i, K.loading(i), K.rate(i), -K.margin_flow(i)];
i = find(K.margin_qmax < -opts.tol.q);
viol = [viol; 4*ones(numel(i),1), i, K.Qg_bus(i), M.bqmax(i)*base, -K.margin_qmax(i)];
i = find(K.margin_qmin < -opts.tol.q);
viol = [viol; 5*ones(numel(i),1), i, K.Qg_bus(i), M.bqmin(i)*base, -K.margin_qmin(i)];
i = find(K.margin_pmax < -opts.tol.p);
viol = [viol; 6*ones(numel(i),1), i, K.Pg(i), M.gpmax(i)*base, -K.margin_pmax(i)];
i = find(K.margin_pmin < -opts.tol.p);
viol = [viol; 7*ones(numel(i),1), i, K.Pg(i), M.gpmin(i)*base, -K.margin_pmin(i)];
if opts.limits.angle
    i = find(dth > M.angmax + opts.tol.angle & M.angmax < 360);
    viol = [viol; 8*ones(numel(i),1), i, dth(i), M.angmax(i), dth(i) - M.angmax(i)];
    i = find(dth < M.angmin - opts.tol.angle & M.angmin > -360);
    viol = [viol; 8*ones(numel(i),1), i, dth(i), M.angmin(i), M.angmin(i) - dth(i)];
end
K.viol = viol;
K.kind_names = {'voltage below limit', 'voltage above limit', 'branch overload', ...
    'reactive power above limit', 'reactive power below limit', ...
    'active power above limit', 'active power below limit', 'angle difference'};
K.kind_units = {'pu', 'pu', K.flow_unit, 'Mvar', 'Mvar', 'MW', 'MW', 'degree'};
K.kind_element = {'bus', 'bus', 'branch', 'bus', 'bus', 'generator', 'generator', 'branch'};
K.count = accumarray(viol(:, 1), 1, [8, 1])';
K.n_viol = size(viol, 1);
K.feasible = K.n_viol == 0;
K.n_at_qlim = nnz(N.atlim);          % generator buses that do not hold their set point
K.n_unresolved = nnz(N.frozen);
K.v_min = min(Vm); K.v_max = max(Vm);
K.max_loading_pct = max([K.loading_pct(has); 0]);
end

function Qg = localSplit(M, Qgb)
% reactive output of a bus shared among its generators in proportion to their range
ng = M.ng; Qg = zeros(ng, 1);
qmin = M.gqmin; qmax = M.gqmax;
fin = isfinite(qmin) & isfinite(qmax);
rng = zeros(ng, 1); rng(fin) = qmax(fin) - qmin(fin);
cnt = full(M.Cg * ones(ng, 1));
allfin = full(M.Cg * double(~fin)) == 0;
rb = full(M.Cg * rng); qminb = full(M.Cg * (qmin .* fin));
for g = 1:ng
    b = M.gbus(g);
    if allfin(b) && rb(b) > 0
        Qg(g) = qmin(g) + (Qgb(b) - qminb(b)) * rng(g) / rb(b);
    else
        Qg(g) = Qgb(b) / cnt(b);
    end
end
end
