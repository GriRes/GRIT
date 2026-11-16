function [P, M, N, K] = GRIT_Repair(M, N, K, opts)
%GRIT_REPAIR  Search a nearby dispatch that satisfies all checked limits.
%   Each round linearizes the limits that are violated or close to
%   violation at the present AC solution, solves a linear program for the
%   smallest change of generator active power (and voltage set points),
%   applies the change and solves the AC equations again. A step is kept
%   only when it reduces the total violation of the new AC solution.
%   Otherwise the step bounds are halved. The repair does not minimize
%   the generation cost.
%
%   The function returns the best dispatch found. P.success is true when
%   the check of its AC solution finds no violation. P.relaxed is true
%   when all remaining violations are inside the tolerances relax.v and
%   relax.flow_pct. P.remaining lists the remaining violations, which is
%   the smallest relaxation of limits found by the repair.
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

base = M.baseMVA; nb = M.nb; ng = M.ng;
Pg0 = M.Pg; Vset0 = M.Vset; K0 = K;
useV = strcmpi(opts.repair.controls, 'pv');
if ~any(strcmpi(opts.repair.controls, {'p', 'pv'}))
    error('GRIT:input', 'Option repair.controls must be ''p'' or ''pv''.');
end
setV = false(nb, 1); setB = false(M.nl, 1); setQ = false(nb, 1);
P.rounds = 0; P.message = ''; P.history = zeros(0, 5); P.kinds = K.count;
nfac = 0; tStart = tic; nostall = 0; scale = 1; tight = 1;
phi = localMeasure(M, K);
budget = max(opts.repair.min_time, opts.repair.time_ratio * N.time);
for round = 1:opts.repair.max_rounds
    if K.feasible, break; end
    if toc(tStart) > budget
        P.message = sprintf('The time limit of the repair (%.1f s) was reached.', budget);
        break;
    end
    if nostall >= 6 || scale < 1/32
        P.message = 'The total violation stopped decreasing.';
        break;
    end
    P.rounds = round;
    hold = false(nb, 1); hold([N.pv; N.ref(isempty(N.rq))]) = true;        % buses that hold a set point
    % ---- limits that enter the linear program
    setV = setV | (~hold & K.margin_v < 0.2 * opts.repair.screen);
    has = M.rate > 0;
    setB = setB | (has & K.margin_flow < 3 * opts.repair.screen * K.rate);
    qr = (M.bqmax - M.bqmin) * base; qr(~isfinite(qr)) = Inf;
    setQ = setQ | (hold & M.isgen & (K.margin_qmax < opts.repair.screen * qr | K.margin_qmin < opts.repair.screen * qr));
    vb = find(setV & ~hold); bb = find(setB); qb = find(setQ & hold);
    q = struct('vbus', vb, 'branch', bb, 'qbus', qb, 'loss', false);
    S = GRIT_Sensitivity(M, N, q, opts); nfac = nfac + 1;
    nv = numel(vb); nbr = numel(bb); nq = numel(qb);
    Gp = S.GP * M.Cg;                                     % per pu generator active power
    gcv = find(hold & M.isgen);
    if ~useV, gcv = zeros(0, 1); end
    Gv = S.GV(:, gcv); ncv = numel(gcv);
    bo = opts.repair.back_off * tight;
    iv = 1:nv; ib = nv + (1:nbr); iq = nv + nbr + (1:nq);
    qbo = bo * min(qr(qb) / base, 1);
    Aup = [Gp(iv, :), Gv(iv, :); Gp(ib, :), Gv(ib, :); Gp(iq, :), Gv(iq, :)];
    bup = [M.vmax(vb) - bo - S.y(iv); M.rate(bb) * (1 - bo) - S.y(ib); M.bqmax(qb) - qbo - S.y(iq)];
    Alo = -[Gp(iv, :), Gv(iv, :); Gp(iq, :), Gv(iq, :)];
    blo = -[M.vmin(vb) + bo - S.y(iv); M.bqmin(qb) + qbo - S.y(iq)];
    A = [Aup; Alo]; b = [bup; blo];
    keep = isfinite(b); A = A(keep, :); b = b(keep);
    nr = size(A, 1);
    % ---- variables [dp+; dp-; dv+; dv-; u]
    PgAC = M.Pg + M.alpha * N.s;
    stepP = scale * opts.repair.step_p * max(M.gpmax, 0); rampP = opts.repair.ramp_pct * max(M.gpmax, 0);
    upP = max(0, min([stepP, rampP - (M.Pg - Pg0), M.gpmax - PgAC], [], 2));
    dnP = max(0, min([stepP, rampP + (M.Pg - Pg0), M.Pg - M.gpmin], [], 2));
    Vs = M.Vset(gcv); stepV = scale * opts.repair.step_v * ones(ncv, 1);
    upV = max(0, min([stepV, opts.repair.dv_max - (Vs - Vset0(gcv)), M.vmax(gcv) - Vs], [], 2));
    dnV = max(0, min([stepV, opts.repair.dv_max + (Vs - Vset0(gcv)), Vs - M.vmin(gcv)], [], 2));
    % a unit above PMAX or a set point outside the voltage limits must move back
    needDn = max(0, PgAC - M.gpmax); needUp = max(0, M.gpmin - PgAC);
    dnP = max(dnP, needDn); upP = max(upP, needUp);
    vDn = max(0, Vs - M.vmax(gcv)); vUp = max(0, M.vmin(gcv) - Vs);
    dnV = max(dnV, vDn); upV = max(upV, vUp);
    Az = [A(:, 1:ng), -A(:, 1:ng), A(:, ng+1:end), -A(:, ng+1:end), -speye(nr)];
    Aeq = [ones(1, ng), -ones(1, ng), zeros(1, 2 * ncv + nr)];
    c = [base * ones(2 * ng, 1); (opts.repair.w_v / 0.01) * ones(2 * ncv, 1); 1e4 * base * ones(nr, 1)];
    lb = [needUp; needDn; vUp; vDn; zeros(nr, 1)];
    ub = [upP; dnP; upV; dnV; inf(nr, 1)];
    [z, ok, msg] = GRIT_LP(c, Az, b, Aeq, 0, lb, ub, budget - toc(tStart));
    if ~ok
        P.message = msg; break;
    end
    dp = z(1:ng) - z(ng+1:2*ng);
    dv = z(2*ng+1:2*ng+ncv) - z(2*ng+ncv+1:2*ng+2*ncv);
    u = z(2*ng+2*ncv+1:end);
    if max(abs(dp)) * base < 1e-6 && (isempty(dv) || max(abs(dv)) < 1e-7)
        if tight < 8, tight = 2 * tight; nostall = nostall + 1; continue; end
        P.message = 'The controls reached their bounds before all limits were satisfied.';
        break;
    end
    % ---- apply the step, halve it when the AC equations have no solution
    fr = 1;
    while true
        Mn = M;
        Mn.Pg = M.Pg + fr * dp;
        Mn.Vset(gcv) = M.Vset(gcv) + fr * dv;
        Mn.Sbus = Mn.Cg * Mn.Pg - Mn.Pd - 1j * Mn.Qd;
        Nn = GRIT_Newton(Mn, opts, struct('V', N.V, 's', N.s, 'atlim', N.atlim));
        nfac = nfac + Nn.n_factor;
        if Nn.converged || fr < 0.2, break; end
        fr = fr / 2;
    end
    if ~Nn.converged
        scale = scale / 2; nostall = nostall + 1;
        continue;
    end
    Kn = GRIT_Check(Mn, Nn, opts);
    phin = localMeasure(Mn, Kn);
    acc = phin < phi;
    P.history(end+1, :) = [round, Kn.n_viol, sum(abs(Mn.Pg - Pg0)) * base / 2, max([u; 0]), acc]; %#ok<AGROW>
    P.kinds(end+1, :) = Kn.count; %#ok<AGROW>
    if acc
        if phin > 0.7 * phi, nostall = nostall + 1; else, nostall = 0; end
        M = Mn; N = Nn; K = Kn; phi = phin;
        if max([u; 0]) < 1e-9 && ~K.feasible
            tight = min(16, 2 * tight);         % the linear model was satisfied, the AC check was not
        end
    else
        scale = scale / 2; nostall = nostall + 1;   % step rejected
        tight = min(8, 2 * tight);
    end
end
P.success = K.feasible;
if P.success, P.message = ''; elseif isempty(P.message)
    P.message = 'The limit on rounds was reached.';
end
% ---- remaining violations and the relaxation they would need
ex = K.viol;
vEx = max([ex(ex(:, 1) <= 2, 5); 0]);
fl = ex(ex(:, 1) == 3, :);
fEx = 0;
if ~isempty(fl), fEx = max(100 * fl(:, 5) ./ fl(:, 4)); end
other = any(ex(:, 1) > 3);
P.need_v = vEx;                 % pu
P.need_flow_pct = fEx;          % percent of the rating
P.need_other = other;           % a generator or angle limit remains violated
P.relaxed = ~P.success && ~other && vEx <= opts.relax.v + 1e-12 && fEx <= opts.relax.flow_pct + 1e-9;
P.remaining = ex;
P.n_factor = nfac;
P.dp = (M.Pg - Pg0) * base;                           % MW by internal generator
P.dv = M.Vset - Vset0;                                % pu by internal bus
P.dp_total = sum(abs(P.dp)) / 2;                      % MW moved from one unit to another
P.n_dp = nnz(abs(P.dp) > 1e-4);
P.n_dv = nnz(abs(P.dv) > 1e-6);
P.gen = [M.map.gen, M.map.bus(M.gbus), Pg0 * base, M.Pg * base, P.dp];
P.gen_cols = {'row', 'bus', 'Pg before (MW)', 'Pg after (MW)', 'change (MW)'};
ch = find(abs(P.dv) > 1e-6);
P.vset = [M.map.bus(ch), Vset0(ch), M.Vset(ch), P.dv(ch)];
P.vset_cols = {'bus', 'set point before', 'set point after', 'change'};
P.n_viol_before = K0.n_viol; P.n_viol_after = K.n_viol;
P.cost_change = NaN;
if isfield(M.mpc, 'gencost') && ~isempty(M.mpc.gencost)
    gc = M.mpc.gencost(M.map.gen, :);
    P.cost_change = sum(totcost(gc, K.Pg)) - sum(totcost(gc, K0.Pg));
end
end

function phi = localMeasure(M, K)
% Total violation: voltage in units of 0.01 pu, branch loading in percent of
% the rating, generator limits in percent of the system base.
v = K.viol; phi = 0;
if isempty(v), return; end
i = v(:, 1) <= 2;  phi = phi + sum(v(i, 5)) / 0.01;
i = v(:, 1) == 3;  phi = phi + sum(100 * v(i, 5) ./ max(v(i, 4), 1e-6));
i = v(:, 1) >= 4 & v(:, 1) <= 7; phi = phi + sum(100 * v(i, 5) / M.baseMVA);
i = v(:, 1) == 8;  phi = phi + sum(v(i, 5));
end
