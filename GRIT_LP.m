function [x, ok, msg] = GRIT_LP(c, A, b, Aeq, beq, lb, ub, tmax)
%GRIT_LP  Linear program  min c'x  s.t.  A x <= b, Aeq x = beq, lb <= x <= ub.
%   The problem is cleaned before it is solved: entries of A that are
%   numerical noise are removed, each row is scaled by its largest entry,
%   and variables with equal bounds are eliminated. Solvers are tried in
%   this order: linprog (Optimization Toolbox), GLPK (Octave), MIPS (ships
%   with MATPOWER). A returned point is accepted only when it satisfies
%   the constraints. TMAX limits the time of linprog (s).
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
if nargin < 8 || isempty(tmax), tmax = 60; end
tmax = max(tmax, 0.2);
n = numel(c); c = c(:); b = b(:); beq = beq(:); lb = lb(:); ub = ub(:);
A = sparse(A); Aeq = sparse(Aeq);
x = min(max(zeros(n, 1), lb), ub); ok = false; msg = 'The linear program has no solution.';
if any(lb > ub + 1e-12)
    msg = 'The linear program has inconsistent bounds.';
    return;
end
% scale rows and drop noise
if ~isempty(A)
    rmax = full(max(abs(A), [], 2)); rmax(rmax == 0) = 1;
    D = sparse(1:numel(rmax), 1:numel(rmax), 1 ./ rmax);
    A = D * A; b = b ./ rmax;
    [i, j, v] = find(A); k = abs(v) > 1e-9;
    A = sparse(i(k), j(k), v(k), size(A, 1), n);
end
% eliminate fixed variables
fix = (ub - lb) <= 1e-12;
xf = lb(fix);
fr = find(~fix);
b2 = b - A(:, fix) * xf; beq2 = beq - Aeq(:, fix) * xf;
A2 = A(:, fr); Ae2 = Aeq(:, fr);
AA = [A2; Ae2];
l = [-inf(size(A2, 1), 1); beq2];
u = [b2; beq2];
lbf = lb(fr); ubf = ub(fr); cf = c(fr); nf = numel(fr);
x0 = min(max(zeros(nf, 1), lbf), ubf);
for k = 1:3
    xk = []; flag = 0;
    ws = warning('off', 'all');
    try
        switch k
            case 1          % linprog of the Optimization Toolbox
                if exist('linprog', 'file') && exist('optimoptions', 'file')
                    o = optimoptions('linprog', 'Display', 'off', 'MaxTime', tmax);
                    [xk, ~, flag] = linprog(cf, A2, b2, Ae2, beq2, lbf, ubf, o);
                end
            case 2          % GLPK (Octave), presolver off
                if exist('glpk', 'file') || exist('glpk', 'builtin')
                    ct = [repmat('U', 1, size(A2, 1)), repmat('S', 1, size(Ae2, 1))];
                    par.presol = 0; par.msglev = 0; par.scale = 0;
                    [xk, ~, st] = glpk(cf, AA, u, lbf, ubf, ct, repmat('C', 1, nf), 1, par);
                    flag = double(st == 0 || st == 5);
                end
            otherwise       % MIPS, ships with MATPOWER
                if nf > 3000, continue; end        % MIPS is too slow for a large linear program
                opt = struct('verbose', 0, 'alg', 'MIPS', 'mips_opt', struct('max_it', 60));
                if exist('qps_master', 'file')
                    [xk, ~, flag] = qps_master([], cf, AA, l, u, lbf, ubf, x0, opt);
                else
                    [xk, ~, flag] = qps_matpower([], cf, AA, l, u, lbf, ubf, x0, opt);
                end
        end
    catch err
        msg = ['The linear program solver failed. ' err.message];
    end
    warning(ws);
    if flag > 0 && numel(xk) == nf && all(isfinite(xk))
        r = AA * xk;
        sc = 1e-6 * (1 + max(abs(xk)));
        if all(r <= u + sc) && all(r >= l - sc) && all(xk >= lbf - sc) && all(xk <= ubf + sc)
            x = zeros(n, 1); x(fix) = xf; x(fr) = min(max(xk, lbf), ubf);
            ok = true; msg = '';
            return;
        end
    end
end
end
