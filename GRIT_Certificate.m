function C = GRIT_Certificate(M, N, opts)
%GRIT_CERTIFICATE  A posteriori existence certificate of the AC solution.
%   The power flow equations are written in rectangular coordinates
%   x = [e; f; s] (real and imaginary parts of the bus voltages except
%   the reference bus, and the loss variable s). In these coordinates
%   every equation is a polynomial of degree two, so the Jacobian matrix
%   J(x) is an affine function of x.
%
%   Quantities at the computed point x0:
%     eta   = norm(J(x0)\F(x0), inf)        size of one more Newton step
%     omega >= norm(J(x0)\(J(x)-J(y)), inf) / norm(x-y, inf) for all x, y
%     h     = eta * omega
%   Newton-Kantorovich theorem: if h <= 1/2, an exact solution x* exists
%   with norm(x*-x0, inf) <= rho_minus = (1-sqrt(1-2h))/omega, and x* is
%   the only solution within rho_plus = (1+sqrt(1-2h))/omega of x0.
%
%   omega is computed as norm(abs(inv(J0))*beta, inf), where beta(m) is
%   the sum of the absolute second derivatives of equation m.
%   Mode 'exact' forms abs(inv(J0))*beta column block by column block.
%   Mode 'estimate' uses a 1-norm estimator with a few solves. The
%   estimate is a lower bound of the exact value. It is not a strict
%   bound. Floating-point rounding is not bounded in either mode.
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

tStart = tic;
mode = lower(opts.cert.mode);
if strcmp(mode, 'auto')
    if M.nb <= opts.cert.exact_max_bus, mode = 'exact'; else, mode = 'estimate'; end
end
if ~any(strcmp(mode, {'exact', 'estimate'}))
    error('GRIT:input', 'Option cert.mode must be ''auto'', ''exact'', ''estimate'' or ''off''.');
end

nb = M.nb; Ybus = M.Ybus; G = real(Ybus); B = imag(Ybus);
ref = N.ref; pv = N.pv; pq = N.pq; a = M.abus; rq = N.rq;
nr = [pv; pq]; m = numel(nr); npv = numel(pv);
V = N.V * exp(-1j * angle(N.V(ref)));      % reference angle zero: f(ref) = 0 is data
e = real(V); f = imag(V);
ev = [nr; rq]; ne = numel(ev);             % buses whose real part is unknown
qr = [pq; rq]; nqr = numel(qr);            % buses with a reactive power equation
I = Ybus * V; S = V .* conj(I);
Ssp = N.Sbus + a * N.s;
Vset2 = abs(V(pv)).^2;                     % PV buses sit on their set points
rp = [nr; ref];
F = [real(S(rp)) - real(Ssp(rp)); imag(S(qr)) - imag(Ssp(qr)); abs(V(pv)).^2 - Vset2];
Ire = real(I); Iim = imag(I);
sd = @(v) sparse(1:nb, 1:nb, v, nb, nb);
dPde = sd(Ire) + sd(e) * G + sd(f) * B;   dPdf = sd(Iim) - sd(e) * B + sd(f) * G;
dQde = -sd(Iim) + sd(f) * G - sd(e) * B;  dQdf = sd(Ire) - sd(f) * B - sd(e) * G;
dVde = 2 * sd(e); dVdf = 2 * sd(f);
nx = ne + m + 1;
J = [dPde(rp, ev), dPdf(rp, nr), sparse(-a(rp)); ...
     dQde(qr, ev), dQdf(qr, nr), sparse(nqr, 1); ...
     dVde(pv, ev), dVdf(pv, nr), sparse(npv, 1)];

% second derivatives: beta(m) = sum over (j,k) of |d2 F_m / dx_j dx_k|
ve = zeros(nb, 1); ve(ev) = 1:ne; vf = zeros(nb, 1); vf(nr) = ne + (1:m);
rP = zeros(nb, 1); rP(rp) = 1:m+1;
rQ = zeros(nb, 1); rQ(qr) = m + 1 + (1:nqr);
rV = zeros(nb, 1); rV(pv) = m + 1 + nqr + (1:npv);
[ii, nn, yy] = find(Ybus); g = real(yy); b = imag(yy);
R  = [rP(ii); rP(ii); rP(ii); rP(ii); rQ(ii); rQ(ii); rQ(ii); rQ(ii)];
A  = [ve(ii); vf(ii); vf(ii); ve(ii); vf(ii); ve(ii); ve(ii); vf(ii)];
Bv = [ve(nn); vf(nn); ve(nn); vf(nn); ve(nn); vf(nn); ve(nn); vf(nn)];
Cv = [g; g; b; -b; g; -g; -b; -b];
R = [R; rV(pv); rV(pv)]; A = [A; ve(pv); vf(pv)]; Bv = [Bv; ve(pv); vf(pv)]; Cv = [Cv; ones(2 * npv, 1)];
k = R > 0 & A > 0 & Bv > 0;
R = R(k); A = A(k); Bv = Bv(k); Cv = Cv(k);
R = [R; R]; A2 = [A; Bv]; B2 = [Bv; A]; Cv = [Cv; Cv];
pid = (A2 - 1) * nx + B2;
[up, ~, pj] = unique(pid);
H = sparse(R, pj, Cv, nx, numel(up));
beta = full(sum(abs(H), 2));

ws = warning('off', 'all');
[L, U, P, Q] = lu(J);
dx = Q * (U \ (L \ (P * F)));
warning(ws);
C.mode = mode;
C.eta = norm(dx, inf);
C.residual = norm(F, inf);
if ~all(isfinite(dx))
    C.omega = Inf; C.h = Inf; C.certified = false;
    C.rho_minus = NaN; C.rho_plus = NaN; C.time = toc(tStart);
    return;
end
if strcmp(mode, 'exact')
    blk = max(1, round(opts.cert.block));
    row = zeros(nx, 1);
    for s0 = 1:blk:nx
        idx = s0:min(nx, s0 + blk - 1);
        E = full(sparse(idx, 1:numel(idx), 1, nx, numel(idx)));
        Z = Q * (U \ (L \ (P * E)));
        row = row + abs(Z) * beta(idx);
    end
    C.omega = max(row);
else
    C.omega = localNorm1(L, U, P, Q, beta, nx);
end
C.h = C.eta * C.omega;
C.certified = isfinite(C.h) && C.h <= 0.5;
if C.certified
    rt = sqrt(1 - 2 * C.h);
    C.rho_plus = (1 + rt) / C.omega;
    if C.h < 1e-8
        C.rho_minus = C.eta * (1 + C.h / 2);     % series of (1-sqrt(1-2h))/omega
    else
        C.rho_minus = (1 - rt) / C.omega;
    end
else
    C.rho_minus = NaN; C.rho_plus = NaN;
end
C.time = toc(tStart);
end

function est = localNorm1(L, U, P, Q, beta, n)
% Estimate of norm(A, 1) with A = diag(beta) * inv(J)', which equals
% norm(abs(inv(J)) * beta, inf). Method of Hager (1984) and Higham (1988).
Amul  = @(x) beta .* (P' * (L' \ (U' \ (Q' * x))));
Atmul = @(x) Q * (U \ (L \ (P * (beta .* x))));
x = ones(n, 1) / n;
est = 0; jlast = 0;
for it = 1:6
    y = Amul(x);
    estNew = norm(y, 1);
    xi = sign(y); xi(xi == 0) = 1;
    z = Atmul(xi);
    [zmax, j] = max(abs(z));
    if it > 1 && (estNew <= est || j == jlast || zmax <= z' * x)
        est = max(est, estNew);
        break;
    end
    est = estNew; jlast = j;
    x = zeros(n, 1); x(j) = 1;
end
% second start vector with alternating signs, as in LAPACK
x = (-1).^(0:n-1)' .* (1 + (0:n-1)' / max(n - 1, 1));
est = max(est, 2 * norm(Amul(x), 1) / (3 * n));
end
