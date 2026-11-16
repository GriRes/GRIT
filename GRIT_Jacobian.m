function [J, dSa, dSm] = GRIT_Jacobian(Ybus, V, ref, pv, pq, a, rq)
%GRIT_JACOBIAN  Jacobian matrix of the power flow equations used by GRIT.
%   Rows: active power of the buses [pv; pq; ref], reactive power of pq.
%   Columns: angles of [pv; pq], magnitudes of pq, loss variable s.
%   RQ is empty, or the reference bus when its reactive output is fixed at
%   a limit. Then its magnitude is one more unknown and its reactive
%   balance one more equation (the list pq is extended by RQ).
%   dSa and dSm are the derivatives of the complex bus injections with
%   respect to all angles and all magnitudes.
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
if nargin < 7, rq = []; end
vq = [pq; rq(:)];
nb = numel(V);
Ibus = Ybus * V;
dV = sparse(1:nb, 1:nb, V, nb, nb);
dI = sparse(1:nb, 1:nb, Ibus, nb, nb);
dN = sparse(1:nb, 1:nb, V ./ abs(V), nb, nb);
dSm = dV * conj(Ybus * dN) + conj(dI) * dN;
dSa = 1j * dV * conj(dI - Ybus * dV);
pp = [pv; pq]; rp = [pv; pq; ref];
J = [real(dSa(rp, pp)), real(dSm(rp, vq)), sparse(-a(rp)); ...
     imag(dSa(vq, pp)), imag(dSm(vq, vq)), sparse(numel(vq), 1)];
end
