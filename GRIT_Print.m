function GRIT_Print(R, fid)
%GRIT_PRINT  Print the summary of a GRIT result.
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
if nargin < 2, fid = 1; end
ln = repmat('-', 1, 72);
fprintf(fid, '%s\nGRIT %s   %s   (%d buses, %d generators, %d branches)\n%s\n', ln, R.version, R.name, R.size.nb, R.size.ng, R.size.nl, ln);
fprintf(fid, 'Verdict            : %s\n', R.verdict);
N = R.newton;
if strcmp(R.verdict, 'NO_SOLUTION')
    fprintf(fid, 'AC solution        : not found. %s\n', N.message);
    D = R.diagnosis;
    fprintf(fid, 'DC solution        : largest angle difference over a branch %.1f degree, %d branches above 60 degree\n', D.max_dc_angle_diff, size(D.wide_branches, 1));
    fprintf(fid, 'Losses             : DC estimate %.1f MW, upward generation headroom %.1f MW\n', D.loss_estimate, D.headroom);
    fprintf(fid, 'Time               : %.3f s (DC dispatch %.3f s)\n%s\n', R.time.total, R.time.dc, ln);
    return;
end
K = R.check;
fprintf(fid, 'AC solution        : %s, %d iterations, %d factorizations\n', N.path, N.iterations, N.n_factor);
fprintf(fid, 'Losses             : %.2f MW shared among generators (DC estimate %.2f MW)\n', K.loss, R.dc.loss_estimate);
fprintf(fid, 'Voltage            : %.4f to %.4f pu\n', K.v_min, K.v_max);
fprintf(fid, 'Largest loading    : %.1f percent\n', K.max_loading_pct);
fprintf(fid, 'DC flow error      : %.2f MW at most\n', R.ac.max_flow_error);
fprintf(fid, 'Units at a Q limit : %d buses do not hold their voltage set point\n', K.n_at_qlim);
if ~isempty(R.repair)
    P = R.repair;
    if P.success
        fprintf(fid, 'Repair             : success in %d rounds, %.2f MW moved, %d set points changed, cost change %+.2f $/h\n', P.rounds, P.dp_total, P.n_dv, P.cost_change);
    else
        fprintf(fid, 'Repair             : %d of %d violations remain after %d rounds. %s\n', P.n_viol_after, P.n_viol_before, P.rounds, P.message);
        fprintf(fid, '                     relaxation needed: voltage %.4f pu, branch loading %.2f percent', P.need_v, P.need_flow_pct);
        if P.need_other, fprintf(fid, ', and a generator limit'); end
        fprintf(fid, '\n');
    end
end
if K.n_viol == 0
    fprintf(fid, 'Violations         : none\n');
else
    fprintf(fid, 'Violations         : %d\n', K.n_viol);
    for k = 1:numel(K.count)
        if K.count(k) > 0
            rows = K.viol(K.viol(:, 1) == k, :);
            fprintf(fid, '   %-28s %4d   largest excess %.4g %s\n', K.kind_names{k}, K.count(k), max(rows(:, 5)), K.kind_units{k});
        end
    end
end
if ~isempty(R.cert)
    C = R.cert;
    if C.certified
        fprintf(fid, 'Existence check    : an exact AC solution lies within %.1e pu of the computed point (h = %.1e, %s)\n', C.rho_minus, C.h, C.mode);
        fprintf(fid, '                     limits with a margin inside the possible change: %d\n', C.undecided);
    else
        fprintf(fid, 'Existence check    : not confirmed (h = %.3g, needed h <= 0.5, %s)\n', C.h, C.mode);
    end
end
fprintf(fid, 'Time               : %.3f s  (solve %.3f, check %.3f, existence check %.3f, repair %.3f, loss factors %.3f)\n', ...
    R.time.total, R.time.solve, R.time.check, R.time.cert, R.time.repair, R.time.price);
fprintf(fid, '                     DC dispatch %.3f s, not included\n%s\n', R.time.dc, ln);
end
