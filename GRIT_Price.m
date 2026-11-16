function Pr = GRIT_Price(M, N, opts) %#ok<INUSD>
%GRIT_PRICE  Marginal loss factors and loss price components at fixed dispatch.
%   itl(i) is the change of the total losses per MW injected at bus i,
%   with the generators sharing the loss change by their participation
%   factors. loss_price(i) = -lambda * itl(i), where lambda is the DC price
%   weighted by the participation factors. lmp_adj = DC price + loss price.
%   These values hold for the fixed DC dispatch. They are not AC-OPF prices.
%   For every branch with a binding DC limit, the AC sensitivity of its
%   loading to bus injections is compared with the DC sensitivity.
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

q = struct('vbus', [], 'branch', [], 'qbus', [], 'loss', true);
bind = find(abs(M.dc.mu_sf(M.map.branch)) + abs(M.dc.mu_st(M.map.branch)) > 1e-6);
ob = opts; ob.limits.flow = 'P';
q.branch = bind;
S = GRIT_Sensitivity(M, N, q, ob);
nk = numel(S.y);
Pr.itl = 1 + S.GP(nk, :)';                              % by internal bus
lmp = M.dc.lmp(localRows(M));
Pr.lambda = sum(M.abus .* lmp);
Pr.loss_price = -Pr.lambda * Pr.itl;
Pr.lmp_dc = lmp;
Pr.lmp_adj = lmp + Pr.loss_price;
Pr.bus = M.map.bus;
Pr.binding = zeros(0, 5);
if ~isempty(bind) && all(isfinite(lmp))
    % DC sensitivities of the same branches, same sharing of the balance
    [PQ, PV, REF, NONE, BUS_I] = idx_bus; %#ok<ASGLU>
    [Bbus, Bf] = makeBdc(M.baseMVA, M.mi.bus, M.mi.branch);
    nr = [M.pv; M.pq];
    X = zeros(numel(bind), M.nb);
    X(:, nr) = (Bbus(nr, nr)' \ Bf(bind, nr)')';
    X = X - (X * M.abus) * ones(1, M.nb);
    sgn = sign(M.dc.pf(M.map.branch(bind))); sgn(sgn == 0) = 1;
    Gac = S.GP(1:numel(bind), :);
    Gdc = X .* (sgn * ones(1, M.nb));
    mu = M.dc.mu_sf(M.map.branch(bind)) + M.dc.mu_st(M.map.branch(bind));
    D = Gac - Gdc;
    Pr.binding = [M.map.branch(bind), M.map.bus(M.fbus(bind)), M.map.bus(M.tbus(bind)), mu, max(abs(D), [], 2)];
    Pr.binding_cols = {'row', 'from', 'to', 'DC shadow price', 'largest AC minus DC sensitivity'};
    Pr.cong_delta = -(D' * mu);                         % price change from the sensitivity difference
else
    Pr.cong_delta = zeros(M.nb, 1);
end
end

function rows = localRows(M)
% rows of the input bus table that correspond to the internal buses
[~, rows] = ismember(M.map.bus, M.mpc.bus(:, 1));
end
