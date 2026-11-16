function file = GRIT_Report(R, file)
%GRIT_REPORT  Write a Markdown report of a GRIT result.
%   FILE = GRIT_REPORT(R) writes GRIT_report_<case>.md in the current
%   folder. FILE = GRIT_REPORT(R, FILE) writes to the given file.
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
if nargin < 1 || ~isstruct(R) || ~isfield(R, 'verdict')
    error('GRIT:input', 'GRIT_Report needs the result structure of GRIT_Run.');
end
if nargin < 2 || isempty(file)
    nm = regexprep(R.name, '[^A-Za-z0-9_]', '_');
    file = fullfile(pwd, ['GRIT_report_' nm '.md']);
end
fid = fopen(file, 'w');
if fid < 0
    error('GRIT:io', 'Cannot write the report file "%s".', file);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
o = R.opts;
fprintf(fid, '# GRIT report: %s\n\n', R.name);
fprintf(fid, 'GRIT %s. Generated %s.\n\n', R.version, datestr(now, 'yyyy-mm-dd HH:MM'));
fprintf(fid, '## Verdict\n\n**%s**\n\n%s\n\n', R.verdict, localMeaning(R.verdict));
fprintf(fid, '## Case and options\n\n');
fprintf(fid, '| Item | Value |\n|---|---|\n');
fprintf(fid, '| Network | %d buses, %d generators, %d branches (in service) |\n', R.size.nb, R.size.ng, R.size.nl);
fprintf(fid, '| Dispatch | %s |\n', localIf(strcmp(R.dc.source, 'dcopf'), 'DC-OPF run by GRIT', 'active power values of the case'));
fprintf(fid, '| Load scaling | %.4g |\n', o.dispatch.load_scale);
fprintf(fid, '| Sharing of losses | %s |\n', o.slack.mode);
fprintf(fid, '| Generator reactive limits | %s |\n', localIf(o.newton.enforce_q, 'enforced (units at a limit release their voltage set point)', 'not enforced'));
fprintf(fid, '| Branch limit | %s, rating %s, scaling %.4g |\n', o.limits.flow, o.limits.rate, o.limits.rate_scale);
fprintf(fid, '| DC cost | %s |\n\n', localNum(R.dc.cost, '%.2f $/h'));

N = R.newton;
if strcmp(R.verdict, 'NO_SOLUTION')
    D = R.diagnosis;
    fprintf(fid, '## AC solution\n\nNo AC solution was found. %s\n\n', N.message);
    fprintf(fid, 'This result is not a proof that no AC solution exists.\n\n');
    fprintf(fid, '| Fact about the DC solution | Value |\n|---|---|\n');
    fprintf(fid, '| Largest angle difference over a branch | %.1f degree |\n', D.max_dc_angle_diff);
    fprintf(fid, '| Branches above 60 degree | %d |\n', size(D.wide_branches, 1));
    fprintf(fid, '| Loss estimate from the DC flows | %.1f MW |\n', D.loss_estimate);
    fprintf(fid, '| Upward generation headroom | %.1f MW |\n\n', D.headroom);
    if ~isempty(D.wide_branches)
        fprintf(fid, '| Branch row | From | To | DC angle difference (degree) | Rating (MVA, 0 = none) |\n|---|---|---|---|---|\n');
        for k = 1:min(20, size(D.wide_branches, 1))
            fprintf(fid, '| %d | %d | %d | %.1f | %.1f |\n', D.wide_branches(k, :));
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, 'Time: %.3f s (DC dispatch %.3f s, not included).\n', R.time.total, R.time.dc);
    return;
end
K = R.check;
fprintf(fid, '## AC solution\n\n');
fprintf(fid, '| Item | Value |\n|---|---|\n');
fprintf(fid, '| Path | %s |\n', N.path);
fprintf(fid, '| Newton iterations, factorizations | %d, %d |\n', N.iterations, N.n_factor);
fprintf(fid, '| Losses shared among generators | %.2f MW (estimate from DC flows %.2f MW) |\n', K.loss, R.dc.loss_estimate);
fprintf(fid, '| Voltage range | %.4f to %.4f pu |\n', K.v_min, K.v_max);
fprintf(fid, '| Largest branch loading | %.1f percent |\n', K.max_loading_pct);
fprintf(fid, '| Largest difference of AC and DC active flow | %.2f MW |\n', R.ac.max_flow_error);
fprintf(fid, '| Generator buses at a reactive limit | %d |\n', K.n_at_qlim);
fprintf(fid, '| Cost of the AC dispatch | %s |\n\n', localNum(R.ac.cost, '%.2f $/h'));

if ~isempty(R.repair)
    P = R.repair;
    fprintf(fid, '## Repair\n\n');
    fprintf(fid, '| Item | Value |\n|---|---|\n');
    fprintf(fid, '| Violations before, after | %d, %d |\n', P.n_viol_before, P.n_viol_after);
    fprintf(fid, '| Rounds | %d |\n', P.rounds);
    fprintf(fid, '| Active power moved | %.2f MW on %d units |\n', P.dp_total, P.n_dp);
    fprintf(fid, '| Voltage set points changed | %d |\n', P.n_dv);
    fprintf(fid, '| Cost change | %s |\n', localNum(P.cost_change, '%+.2f $/h'));
    if ~P.success
        fprintf(fid, '| Relaxation still needed | voltage %.4f pu, branch loading %.2f percent%s |\n', P.need_v, P.need_flow_pct, localIf(P.need_other, ', and a generator limit', ''));
        fprintf(fid, '| Note | %s |\n', P.message);
    end
    fprintf(fid, '\nThe repair searches a nearby dispatch that satisfies the checked limits. It does not minimize the generation cost.\n\n');
    ch = find(abs(P.gen(:, 5)) > 1e-3);
    if ~isempty(ch) && (P.success || P.relaxed)
        [~, od] = sort(abs(P.gen(ch, 5)), 'descend'); ch = ch(od);
        fprintf(fid, '| Generator row | Bus | Before (MW) | After (MW) | Change (MW) |\n|---|---|---|---|---|\n');
        for k = 1:min(30, numel(ch))
            fprintf(fid, '| %d | %d | %.2f | %.2f | %+.2f |\n', P.gen(ch(k), :));
        end
        fprintf(fid, '\n');
    end
end

fprintf(fid, '## Violations\n\n');
if K.n_viol == 0
    fprintf(fid, 'None. All checked limits hold at the AC solution.\n\n');
else
    fprintf(fid, '%d limits are violated.\n\n| Kind | Count | Largest excess |\n|---|---|---|\n', K.n_viol);
    for k = 1:numel(K.count)
        if K.count(k) > 0
            rows = K.viol(K.viol(:, 1) == k, :);
            fprintf(fid, '| %s | %d | %.4g %s |\n', K.kind_names{k}, K.count(k), max(rows(:, 5)), K.kind_units{k});
        end
    end
    T = R.violations;
    fprintf(fid, '\n| Kind | Element | Value | Limit | Excess | Unit |\n|---|---|---|---|---|---|\n');
    for k = 1:min(50, size(T, 1))
        fprintf(fid, '| %s | %s | %.4f | %.4f | %.4f | %s |\n', T{k, :});
    end
    if size(T, 1) > 50, fprintf(fid, '\nThe table shows the first 50 of %d rows.\n', size(T, 1)); end
    fprintf(fid, '\n');
end
if isfield(K, 'n_band') && K.n_band > 0
    fprintf(fid, 'With a reactive load uncertainty of %.1f percent, %d more limits can be crossed (first-order estimate).\n\n', 100 * o.q_margin, K.n_band);
end

if ~isempty(R.cert)
    C = R.cert;
    fprintf(fid, '## Existence check of the AC solution\n\n');
    if C.certified
        fprintf(fid, ['The Newton-Kantorovich condition holds at the computed point (h = %.2e, required h <= 0.5, constant by the %s method). ' ...
            'An exact solution of the AC equations lies within %.1e pu of the computed voltages. ' ...
            'Limits whose margin is smaller than the possible change: %d.\n\n'], C.h, C.mode, C.rho_minus, C.undecided);
    else
        fprintf(fid, 'The Newton-Kantorovich condition was not confirmed (h = %.3g, required h <= 0.5).\n\n', C.h);
    end
    fprintf(fid, 'The computation uses floating-point arithmetic without rounding control.\n\n');
end

if ~isempty(R.price)
    Pr = R.price;
    fprintf(fid, '## Marginal loss factors at the fixed dispatch\n\n');
    fprintf(fid, '| Item | Value |\n|---|---|\n');
    fprintf(fid, '| Loss factor range | %.4f to %.4f MW per MW |\n', min(Pr.itl), max(Pr.itl));
    if isfinite(Pr.lambda)
        fprintf(fid, '| Reference price | %.2f $/MWh |\n', Pr.lambda);
        fprintf(fid, '| Loss price component range | %.2f to %.2f $/MWh |\n', min(Pr.loss_price), max(Pr.loss_price));
    end
    fprintf(fid, '| Branches with a binding DC limit | %d |\n\n', size(Pr.binding, 1));
    fprintf(fid, 'These values hold for the fixed dispatch. They are not AC-OPF prices.\n\n');
end

if ~isempty(R.compare)
    Cm = R.compare;
    fprintf(fid, '## Comparison with MATPOWER (comparison only)\n\n| Item | Value |\n|---|---|\n');
    if ~isnan(Cm.pf_success), fprintf(fid, '| AC power flow | converged %d, largest voltage difference %.2e pu, %.3f s |\n', Cm.pf_success, Cm.pf_max_dv, Cm.pf_time); end
    if ~isnan(Cm.opf_success), fprintf(fid, '| AC-OPF | converged %d, cost %s, %.3f s |\n', Cm.opf_success, localNum(Cm.opf_cost, '%.2f $/h'), Cm.opf_time); end
    fprintf(fid, '\n');
end
fprintf(fid, '## Time\n\n| Stage | Seconds |\n|---|---|\n');
fprintf(fid, '| AC solution | %.3f |\n| Check | %.3f |\n| Existence check | %.3f |\n| Repair | %.3f |\n| Loss factors | %.3f |\n| Total | %.3f |\n| DC dispatch (not included) | %.3f |\n', ...
    R.time.solve, R.time.check, R.time.cert, R.time.repair, R.time.price, R.time.total, R.time.dc);
end

function s = localMeaning(v)
switch v
    case 'FEASIBLE',    s = 'The DC dispatch has an AC solution and all checked limits hold.';
    case 'VIOLATED',    s = 'The DC dispatch has an AC solution. At least one checked limit is violated.';
    case 'REPAIRED',    s = 'The DC dispatch violated limits. The repair found a nearby dispatch whose AC solution satisfies all checked limits.';
    case 'RELAXED',     s = 'The repair left violations. All of them are inside the relaxation set by the user.';
    otherwise,          s = 'No AC solution was found for the DC dispatch.';
end
end

function s = localIf(c, a, b)
if c, s = a; else, s = b; end
end

function s = localNum(x, fmt)
if isempty(x) || ~isfinite(x), s = 'not available'; else, s = sprintf(fmt, x); end
end
