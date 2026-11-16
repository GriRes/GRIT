function N = GRIT_Solve(M, opts)
%GRIT_SOLVE  AC solution for the DC dispatch with fallbacks.
%   Step 1: Newton from the DC point. Step 2 (vm_init = 'auto'): Newton
%   from the DC angles with the magnitudes stored in the case. Step 3
%   (newton.continuation): the injections are scaled from zero toward
%   their full value to locate where the solution is lost. Generator
%   buses hold their set points along this path.
%   N.reach is the largest fraction of the injections with a solution
%   (1 when the full dispatch has a solution).
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

N = GRIT_Newton(M, opts);
nfac = N.n_factor; tAll = N.time;
N.reach = double(N.converged);
N.path = 'Newton from the DC point';
if ~N.converged && strcmpi(opts.newton.vm_init, 'auto')
    st.V = GRIT_StartPoint(M, M.Vset, 'case');
    N2 = GRIT_Newton(M, opts, st);
    nfac = nfac + N2.n_factor; tAll = tAll + N2.time;
    if N2.converged
        N = N2; N.reach = 1;
        N.path = 'Newton from the DC angles and the voltage magnitudes of the case';
    end
end
if ~N.converged && opts.newton.continuation
    first = N;
    V = M.Vset; V(~M.isgen) = 1; V = V + 0j;
    t = 0; dt = 0.25; s = 0; last = [];
    oc = opts; oc.newton.enforce_q = false;      % set points are held along the path
    while t < 1 - 1e-9 && dt >= 1/64 && nfac < opts.newton.cont_max_fact
        tn = min(1, t + dt);
        st = struct('V', V, 's', s, 'Sbus', tn * M.Sbus);
        Nk = GRIT_Newton(M, oc, st);
        nfac = nfac + Nk.n_factor; tAll = tAll + Nk.time;
        if Nk.converged
            t = tn; V = Nk.V; s = Nk.s; last = Nk;
            dt = min(2 * dt, 0.25);
        else
            dt = dt / 2;
        end
    end
    if t >= 1 - 1e-9 && opts.newton.enforce_q
        last = GRIT_Newton(M, opts, struct('V', V, 's', s));
        nfac = nfac + last.n_factor; tAll = tAll + last.time;
    end
    if t >= 1 - 1e-9 && last.converged
        N = last; N.reach = 1;
        N.path = 'continuation in the injections';
    else
        N = first; N.reach = t;
        N.path = 'no solution found';
        N.message = sprintf(['%s The continuation in the injections found a solution up to ' ...
            '%.1f percent of the dispatch and load (generator voltage set points held).'], first.message, 100 * t);
    end
end
N.n_factor = nfac;
N.time = tAll;
end
