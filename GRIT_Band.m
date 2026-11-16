function K = GRIT_Band(M, N, K, opts)
%GRIT_BAND  Effect of reactive load uncertainty on limits that are close.
%   Every reactive load may deviate by +/- q_margin times its absolute
%   value. For each voltage and branch loading within the screening
%   distance of its limit, the first-order worst case is
%   sum_i |dy/dQ_i| * q_margin * |Qd_i|. K.band lists the quantities
%   whose worst case crosses the limit: [kind, index, value, band, limit].
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
base = M.baseMVA; hold = false(M.nb, 1); hold([N.pv; N.ref(isempty(N.rq))]) = true;
dq = opts.q_margin * abs(M.Qd);
vb = find(~hold & K.margin_v >= 0 & K.margin_v < 0.02);
has = M.rate > 0;
bb = find(has & K.margin_flow >= 0 & K.margin_flow < 0.1 * K.rate);
q = struct('vbus', vb, 'branch', bb, 'qbus', [], 'loss', false);
K.band = zeros(0, 5);
if isempty(vb) && isempty(bb), K.n_band = 0; return; end
S = GRIT_Sensitivity(M, N, q, opts);
band = abs(S.GQ) * dq;
nv = numel(vb);
bv = band(1:nv); bf = band(nv+1:end) * base;
i = find(bv > K.margin_v(vb));
lim = M.vmax(vb(i)); lo = (K.Vm(vb(i)) - M.vmin(vb(i))) < (M.vmax(vb(i)) - K.Vm(vb(i))); lim(lo) = M.vmin(vb(i(lo)));
K.band = [K.band; 1 + ~lo, vb(i), K.Vm(vb(i)), bv(i), lim];
j = find(bf > K.margin_flow(bb));
K.band = [K.band; 3 * ones(numel(j), 1), bb(j), K.loading(bb(j)), bf(j), K.rate(bb(j))];
K.n_band = size(K.band, 1);
end
