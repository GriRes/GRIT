function B = GRIT_Batch(input, mode, varargin)
%GRIT_BATCH  Check many scenarios of one case.
%   B = GRIT_BATCH(CASE, 'load', SCALES, ...) runs GRIT_RUN once for every
%   load scaling factor in the vector SCALES (for example the periods of
%   a day). Every scenario has its own DC dispatch.
%
%   B = GRIT_BATCH(CASE, 'n-1', BRANCHES, ...) keeps the DC dispatch of
%   the intact network and removes one branch at a time. BRANCHES lists
%   rows of the branch table. An empty list means every in-service
%   branch. Each outage costs one AC solution that starts from the
%   solution of the intact network. A branch whose removal splits the
%   network is reported as 'ISLAND' and is not solved.
%
%   Further arguments are options as in GRIT_RUN. The repair and the
%   price information are switched off in the 'n-1' mode.
%
%   B.table has one row per scenario:
%   [scenario value, verdict code, violations, lowest voltage (pu),
%    largest loading (percent), time (s)]
%   Verdict codes: 1 FEASIBLE, 2 VIOLATED, 3 REPAIRED, 4 RELAXED,
%   5 NO_SOLUTION, 6 ISLAND.
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

if nargin < 3
    error('GRIT:input', 'GRIT_Batch needs a case, a mode and a list of scenarios.');
end
list = varargin{1};
opts = GRIT_Config(varargin{2:end});
names = {'FEASIBLE', 'VIOLATED', 'REPAIRED', 'RELAXED', 'NO_SOLUTION', 'ISLAND'};
B.mode = lower(mode); B.verdict_names = names;
B.cols = {'scenario', 'verdict code', 'violations', 'lowest voltage (pu)', 'largest loading (percent)', 'time (s)'};
tAll = tic;
switch lower(mode)
    case 'load'
        if ~isnumeric(list) || isempty(list) || any(~isfinite(list(:))) || any(list(:) <= 0)
            error('GRIT:input', 'The list of load scaling factors must hold positive numbers.');
        end
        list = list(:); n = numel(list);
        T = nan(n, 6); V = cell(n, 1); msg = cell(n, 1);
        o = opts; o.verbose = 0;
        for k = 1:n
            o.dispatch.load_scale = opts.dispatch.load_scale * list(k);
            T(k, 1) = list(k);
            try
                R = GRIT_Run(input, o);
                [T(k, 2:6), V{k}] = localRow(R, names);
                msg{k} = '';
                if strcmp(R.verdict, 'NO_SOLUTION'), msg{k} = R.newton.message; end
            catch err
                if isempty(strfind(err.identifier, 'GRIT:')), rethrow(err); end %#ok<STREMP>
                T(k, 2) = 5; V{k} = 'NO_SOLUTION'; msg{k} = err.message;
            end
        end
    case {'n-1', 'n1'}
        o = opts; o.verbose = 0; o.repair.enable = false; o.price.enable = false;
        M = GRIT_Model(input, o);
        N0 = GRIT_Solve(M, o);
        if ~N0.converged
            error('GRIT:batch', 'The intact network has no AC solution. %s', N0.message);
        end
        if isempty(list), list = M.map.branch; end
        list = list(:); n = numel(list);
        [tf, loc] = ismember(list, M.map.branch);
        if ~all(tf)
            error('GRIT:input', 'Branch row %d is not an in-service branch of the case.', list(find(~tf, 1)));
        end
        T = nan(n, 6); V = cell(n, 1); msg = cell(n, 1);
        K0 = GRIT_Check(M, N0, o);
        B.base = struct('verdict', names{2 - K0.feasible}, 'violations', K0.n_viol);
        for k = 1:n
            t = tic; l = loc(k);
            T(k, 1) = list(k); msg{k} = '';
            keep = true(M.nl, 1); keep(l) = false;
            adj = sparse([M.fbus(keep); M.tbus(keep)], [M.tbus(keep); M.fbus(keep)], 1, M.nb, M.nb);
            if ~localConnected(adj, M.ref)
                T(k, 2) = 6; V{k} = 'ISLAND'; T(k, 6) = toc(t);
                continue;
            end
            Mk = M;
            br = M.mi.branch; br(l, 11) = 0;                 % BR_STATUS
            [Mk.Ybus, Yf, Yt] = makeYbus(M.baseMVA, M.mi.bus, br);
            Mk.Yf = Yf; Mk.Yt = Yt;
            Mk.Yf(l, :) = 0; Mk.Yt(l, :) = 0;
            Nk = GRIT_Newton(Mk, o, struct('V', N0.V, 's', N0.s));
            if ~Nk.converged
                Nk = GRIT_Newton(Mk, o);
            end
            if ~Nk.converged
                T(k, 2) = 5; V{k} = 'NO_SOLUTION'; msg{k} = Nk.message; T(k, 6) = toc(t);
                continue;
            end
            Kk = GRIT_Check(Mk, Nk, o);
            T(k, 2) = 2 - Kk.feasible; V{k} = names{T(k, 2)};
            T(k, 3) = Kk.n_viol; T(k, 4) = Kk.v_min; T(k, 5) = Kk.max_loading_pct; T(k, 6) = toc(t);
        end
    otherwise
        error('GRIT:input', 'The batch mode must be ''load'' or ''n-1''.');
end
B.table = T; B.verdict = V; B.message = msg;
B.count = accumarray(T(:, 2), 1, [6, 1])';
B.time = toc(tAll);
if opts.verbose > 0
    fprintf('GRIT batch (%s): %d scenarios in %.2f s\n', B.mode, size(T, 1), B.time);
    for k = 1:6
        if B.count(k) > 0, fprintf('   %-12s %d\n', names{k}, B.count(k)); end
    end
end
end

function [row, v] = localRow(R, names)
v = R.verdict;
code = find(strcmp(v, names));
if isempty(R.check)
    row = [code, NaN, NaN, NaN, R.time.total];
else
    row = [code, R.check.n_viol, R.check.v_min, R.check.max_loading_pct, R.time.total];
end
end

function ok = localConnected(adj, start)
nb = size(adj, 1);
seen = false(nb, 1); seen(start) = true; front = start;
while ~isempty(front)
    [nxt, ~] = find(adj(:, front));
    nxt = unique(nxt); nxt = nxt(~seen(nxt));
    seen(nxt) = true; front = nxt;
end
ok = all(seen);
end
