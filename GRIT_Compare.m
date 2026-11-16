function Cm = GRIT_Compare(M, N, K, opts)
%GRIT_COMPARE  Comparison with MATPOWER. Used for comparison only.
%   compare.pf   AC power flow of MATPOWER for the same dispatch. MATPOWER
%                assigns all losses to the reference bus, so the results
%                agree with GRIT only when slack.mode is 'single'.
%   compare.opf  AC-OPF of MATPOWER: cost and time.
%   Values are NaN when the MATPOWER run does not converge.
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
[PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM] = idx_bus; %#ok<ASGLU>
mpopt = mpoption('verbose', 0, 'out.all', 0);
Cm = struct('pf_success', NaN, 'pf_max_dv', NaN, 'pf_time', NaN, ...
    'opf_success', NaN, 'opf_cost', NaN, 'opf_time', NaN);
if opts.compare.pf
    mp = M.mpc; mp.gen(M.map.gen, 2) = M.Pg * M.baseMVA; mp.gen(M.map.gen, 6) = M.Vset(M.gbus);
    t = tic;
    r = runpf(mp, mpoption(mpopt, 'pf.enforce_q_lims', double(opts.newton.enforce_q)));
    Cm.pf_time = toc(t); Cm.pf_success = r.success;
    if r.success
        [~, loc] = ismember(M.map.bus, r.bus(:, BUS_I));
        Cm.pf_max_dv = max(abs(r.bus(loc, VM) - K.Vm));
    end
end
if opts.compare.opf && isfield(M.mpc, 'gencost') && ~isempty(M.mpc.gencost)
    t = tic;
    r = runopf(M.mpc, mpopt);
    Cm.opf_time = toc(t); Cm.opf_success = r.success;
    if r.success, Cm.opf_cost = r.f; end
end
end
