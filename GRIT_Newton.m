function N = GRIT_Newton(M, opts, start)
%GRIT_NEWTON  AC power flow solution that starts from the DC point.
%   N = GRIT_NEWTON(M, OPTS) solves the AC power flow equations for the
%   DC dispatch in M. The start point has the DC angles. Generator buses
%   start at their voltage set points. The iteration is Newton's method in
%   polar coordinates with step halving.
%
%   Unknowns: angles of all buses except the reference bus, magnitudes of
%   the PQ buses, and one scalar s (pu). The scalar is the active power
%   that the generators add to the DC dispatch to cover the losses. Bus i
%   receives the share M.abus(i) of s. Equations: active power balance of
%   every bus and reactive power balance of the PQ buses.
%
%   A generator bus whose reactive power reaches a limit stops holding its
%   set point (PV to PQ). It returns to its set point when the limit is no
%   longer active.
%
%   N = GRIT_NEWTON(M, OPTS, START) uses the fields V, s, Vset, Sbus and
%   atlim (limit state by bus) of START where present.
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

nb = M.nb; Ybus = M.Ybus;
ref = M.ref; pv = M.pv; pq = M.pq;
Sbus = M.Sbus; Vset = M.Vset; a = M.abus;
tol = opts.newton.tol;
tStart = tic;

if nargin < 3, start = []; end
if isfield(start, 'Vset'), Vset = start.Vset; end
if isfield(start, 'Sbus'), Sbus = start.Sbus; end
if isfield(start, 'V')
    V = start.V; initName = 'given';
else
    initName = lower(opts.newton.vm_init);
    V = GRIT_StartPoint(M, Vset, initName);
end
if isfield(start, 's'), s = start.s; else, s = M.loss_dc; end
Qd = -imag(Sbus);                % reactive load seen by the limit check
atlim = zeros(nb, 1);            % +1 at upper Q limit, -1 at lower Q limit
if isfield(start, 'atlim') && opts.newton.enforce_q
    % continue from a known limit state (used by the repair)
    atlim = start.atlim(:); atlim(~M.isgen) = 0;
    up = find(atlim > 0 & isfinite(M.bqmax)); dn = find(atlim < 0 & isfinite(M.bqmin));
    atlim(:) = 0; atlim(up) = 1; atlim(dn) = -1;
    Sbus(up) = real(Sbus(up)) + 1j * (M.bqmax(up) - Qd(up));
    Sbus(dn) = real(Sbus(dn)) + 1j * (M.bqmin(dn) - Qd(dn));
    isPQ = true(nb, 1); isPQ(ref) = false; isPQ(M.isgen & atlim == 0) = false;
    pq = find(isPQ); pv = find(~isPQ); pv(pv == ref) = [];
end
rq = ref(atlim(ref) ~= 0);       % reference bus with reactive output fixed at a limit
gb = [ref(atlim(ref) == 0); pv];
V(gb) = Vset(gb) .* exp(1j * angle(V(gb)));
nswitch = zeros(nb, 1);
frozen = false(nb, 1);
logI = zeros(0, 4); nlu = 0; rounds = 0;
converged = false; msg = '';
it = 0;
while true
    mis = V .* conj(Ybus * V) - Sbus - a * s;
    vq = [pq; rq];
    F = [real(mis([pv; pq; ref])); imag(mis(vq))];
    nF = norm(F, inf);
    if ~all(isfinite(F))
        msg = 'The iteration produced values that are not finite.';
        break;
    end
    if nF < tol
        changed = false;
        if opts.newton.enforce_q && rounds < opts.newton.q_rounds
            Qg = imag(V .* conj(Ybus * V)) + Qd;
            cand = [pv; ref(atlim(ref) == 0)];
            up = cand(Qg(cand) > M.bqmax(cand) + opts.newton.q_tol);
            dn = cand(Qg(cand) < M.bqmin(cand) - opts.newton.q_tol);
            sw = find(atlim ~= 0 & ~frozen);
            Vm = abs(V);
            back = sw((atlim(sw) > 0 & Vm(sw) > Vset(sw) + opts.newton.v_tol) | ...
                      (atlim(sw) < 0 & Vm(sw) < Vset(sw) - opts.newton.v_tol));
            if ~isempty(up) || ~isempty(dn) || ~isempty(back)
                changed = true; rounds = rounds + 1;
                atlim(up) = 1; atlim(dn) = -1;
                Sbus(up) = real(Sbus(up)) + 1j * (M.bqmax(up) - Qd(up));
                Sbus(dn) = real(Sbus(dn)) + 1j * (M.bqmin(dn) - Qd(dn));
                nswitch(back) = nswitch(back) + 1;
                stay = back(nswitch(back) > 2);          % stop repeated switching
                frozen(stay) = true;
                back = back(nswitch(back) <= 2);
                atlim(back) = 0;
                Sbus(back) = real(Sbus(back)) - 1j * Qd(back);
                V(back) = Vset(back) .* exp(1j * angle(V(back)));
                isPQ = true(nb, 1); isPQ(ref) = false;
                isPQ(M.isgen & atlim == 0) = false;
                pq = find(isPQ); pv = find(~isPQ); pv(pv == ref) = [];
                rq = ref(atlim(ref) ~= 0);
            end
        end
        if ~changed
            converged = true;
            break;
        end
        continue;
    end
    if it >= opts.newton.max_it
        msg = sprintf('No convergence in %d iterations. Largest mismatch %.3g pu.', it, nF);
        break;
    end
    it = it + 1;
    J = GRIT_Jacobian(Ybus, V, ref, pv, pq, a, rq);
    ws = warning('off', 'all');
    dx = -(J \ F);
    warning(ws);
    nlu = nlu + 1;
    if ~all(isfinite(dx))
        msg = 'The Jacobian matrix is singular at an iterate.';
        break;
    end
    npp = numel(pv) + numel(pq); nvq = numel(vq);
    lam = 1; f0 = norm(F);
    while true
        Va = angle(V); Vm = abs(V);
        Va([pv; pq]) = Va([pv; pq]) + lam * dx(1:npp);
        Vm(vq) = Vm(vq) + lam * dx(npp+1:npp+nvq);
        sn = s + lam * dx(end);
        Vn = Vm .* exp(1j * Va);
        misn = Vn .* conj(Ybus * Vn) - Sbus - a * sn;
        f1 = norm([real(misn([pv; pq; ref])); imag(misn(vq))]);
        okStep = isfinite(f1) && all(Vm > 0);
        if (okStep && f1 <= (1 - 1e-4 * lam) * f0) || lam <= opts.newton.step_min
            break;
        end
        lam = lam / 2;
    end
    logI(end+1, :) = [it, nF, lam, norm(dx, inf)]; %#ok<AGROW>
    if ~okStep || f1 > f0
        msg = sprintf('The step halving found no reduction of the mismatch. Largest mismatch %.3g pu.', nF);
        break;
    end
    V = Vn; s = sn;
end

N.converged = converged;
N.message = msg;
N.V = V;
N.s = s;                      % active power added to the DC dispatch (pu)
N.Sbus = Sbus;                % specified injections with Q fixed at buses on a limit
N.Vset = Vset;
N.ref = ref; N.pv = pv; N.pq = pq;
N.rq = rq;                    % reference bus when its reactive output is at a limit, else empty
N.atlim = atlim;              % by bus
N.frozen = frozen;
N.iterations = it;
N.q_rounds = rounds;
N.n_factor = nlu;
N.log = logI;                 % iteration, mismatch before the step, damping, step size
N.mismatch = nF;
N.init = initName;
N.time = toc(tStart);
end
