function S = GRIT_Sensitivity(M, N, q, opts)
%GRIT_SENSITIVITY  First-order sensitivities of selected quantities at the AC solution.
%   q.vbus    buses whose voltage magnitude is wanted
%   q.branch  branches whose loading is wanted (the end with the larger loading)
%   q.qbus    generator buses whose reactive output is wanted
%   q.loss    true adds the loss variable s
%   Rows of the result follow the order [vbus; branch; qbus; loss].
%   S.GP(k,i)  change of quantity k per pu active injection at bus i
%   S.GQ(k,i)  per pu reactive injection at bus i (PQ buses)
%   S.GV(k,i)  per pu voltage set point at bus i (buses that hold a set point)
%   S.y        present value of each quantity (pu)
%   The cost is one factorization and one transposed solve per quantity.
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

nb = M.nb; V = N.V; ref = N.ref; pv = N.pv; pq = N.pq;
rq = N.rq; vq = [pq; rq];
pp = [pv; pq]; rp = [pv; pq; ref]; gc = [pv; ref(isempty(rq))];
npp = numel(pp); nvq = numel(vq);
[J, dSa, dSm] = GRIT_Jacobian(M.Ybus, V, ref, pv, pq, M.abus, rq);
nx = size(J, 1);
vbus = q.vbus(:); br = q.branch(:); qbus = q.qbus(:);
nv = numel(vbus); nbr = numel(br); nq = numel(qbus); nls = double(q.loss);
nk = nv + nbr + nq + nls;
Da = sparse(nk, nb); Dm = sparse(nk, nb); y = zeros(nk, 1);

% voltage magnitudes
if nv > 0
    Dm(1:nv, :) = sparse(1:nv, vbus, 1, nv, nb);
    y(1:nv) = abs(V(vbus));
end
% branch loadings
if nbr > 0
    dV = sparse(1:nb, 1:nb, V, nb, nb);
    dN = sparse(1:nb, 1:nb, V ./ abs(V), nb, nb);
    Sf = V(M.fbus(br)) .* conj(M.Yf(br, :) * V);
    St = V(M.tbus(br)) .* conj(M.Yt(br, :) * V);
    If = M.Yf(br, :) * V; It = M.Yt(br, :) * V;
    switch upper(opts.limits.flow)
        case 'S', useF = abs(Sf) >= abs(St);
        case 'P', useF = abs(real(Sf)) >= abs(real(St));
        otherwise, useF = abs(If) >= abs(It);
    end
    Yb = M.Yt(br, :); eb = M.tbus(br);
    Yb(useF, :) = M.Yf(br(useF), :); eb(useF) = M.fbus(br(useF));
    Ib = Yb * V; Vb = V(eb); Sb = Vb .* conj(Ib);
    Cb = sparse(1:nbr, eb, 1, nbr, nb);
    sdg = @(v) sparse(1:nbr, 1:nbr, v, nbr, nbr);
    dSa_b = 1j * (sdg(conj(Ib)) * Cb * dV - sdg(Vb) * conj(Yb * dV));
    dSm_b = sdg(Vb) * conj(Yb * dN) + sdg(conj(Ib)) * Cb * dN;
    switch upper(opts.limits.flow)
        case 'S'
            w = conj(Sb) ./ max(abs(Sb), 1e-12);
            ra = real(sdg(w) * dSa_b); rm = real(sdg(w) * dSm_b); yb = abs(Sb);
        case 'P'
            sg = sign(real(Sb)); sg(sg == 0) = 1;
            ra = sdg(sg) * real(dSa_b); rm = sdg(sg) * real(dSm_b); yb = abs(real(Sb));
        otherwise
            w = conj(Ib) ./ max(abs(Ib), 1e-12);
            ra = real(sdg(w) * (Yb * (1j * dV))); rm = real(sdg(w) * (Yb * dN)); yb = abs(Ib);
    end
    Da(nv+1:nv+nbr, :) = ra; Dm(nv+1:nv+nbr, :) = rm; y(nv+1:nv+nbr) = yb;
end
% reactive output of generator buses
if nq > 0
    Da(nv+nbr+1:nv+nbr+nq, :) = imag(dSa(qbus, :));
    Dm(nv+nbr+1:nv+nbr+nq, :) = imag(dSm(qbus, :));
    Sc = V(qbus) .* conj(M.Ybus(qbus, :) * V);
    y(nv+nbr+1:nv+nbr+nq) = imag(Sc) + M.Qd(qbus);
end
Yx = [Da(:, pp), Dm(:, vq), sparse(nk, 1)]';
if nls
    Yx(nx, nk) = 1; y(nk) = N.s;
end
ws = warning('off', 'all');
lam = (J') \ full(Yx);                               % nx by nk
warning(ws);
GP = zeros(nk, nb); GQ = zeros(nk, nb); GV = zeros(nk, nb);
GP(:, rp) = lam(1:npp+1, :)';
GQ(:, vq) = lam(npp+2:npp+1+nvq, :)';
GV(:, gc) = full(Dm(:, gc)) - lam' * [real(dSm(rp, gc)); imag(dSm(vq, gc))];
S.GP = GP; S.GQ = GQ; S.GV = GV; S.y = y;
S.kind = [ones(nv, 1); 2 * ones(nbr, 1); 3 * ones(nq, 1); 4 * ones(nls, 1)];
S.index = [vbus; br; qbus; zeros(nls, 1)];
end
