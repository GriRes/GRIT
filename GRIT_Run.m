function R = GRIT_Run(input, varargin)
%GRIT_RUN  Check the AC feasibility of a DC dispatch.
%   R = GRIT_RUN(CASE) loads the MATPOWER case, runs the DC-OPF, solves
%   the AC power flow equations for the DC dispatch and checks every
%   operating limit at the AC solution.
%   R = GRIT_RUN(CASE, OPTS) uses the option structure OPTS (see
%   GRIT_CONFIG). R = GRIT_RUN(CASE, 'name', value, ...) sets options by
%   name.
%
%   R.verdict is one of
%     'FEASIBLE'      an AC solution exists and all checked limits hold
%     'VIOLATED'      an AC solution exists and at least one limit is violated
%     'REPAIRED'      limits were violated and the repair found a dispatch
%                     that satisfies all of them (verified by AC solution)
%     'RELAXED'       the repair left violations, all of them inside the
%                     tolerances relax.v and relax.flow_pct set by the user
%     'NO_SOLUTION'   no AC solution was found (this is not a proof that
%                     none exists)
%   See also GRIT_CONFIG, GRIT_REPORT, GRIT_GUI.
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

if nargin < 1
    error('GRIT:input', 'GRIT_Run needs a case name or a case structure.');
end
opts = GRIT_Config(varargin{:});
if ~exist('rundcopf', 'file') || ~exist('makeYbus', 'file')
    error('GRIT:matpower', 'MATPOWER is not on the path. Install MATPOWER and run its install_matpower script.');
end
tAll = tic;
M = GRIT_Model(input, opts);
R.version = GRIT_Version();
R.name = M.name;
R.opts = opts;
R.size = struct('nb', M.nb, 'ng', M.ng, 'nl', M.nl);

% ---- AC solution
N = GRIT_Solve(M, opts);
R.newton = rmfield(N, {'V', 'Sbus'});
R.time.dc = M.time_dc;
R.time.solve = N.time;
R.repair = [];
R.price = [];
if ~N.converged
    R.verdict = 'NO_SOLUTION';
    R.check = []; R.cert = []; R.compare = [];
    R.dc = localDC(M);
    R.diagnosis = localDiagnose(M);
    R.time.check = 0; R.time.cert = 0; R.time.repair = 0; R.time.price = 0;
    R.time.total = toc(tAll) - M.time_dc;
    R.model = M;
    if opts.verbose > 0, GRIT_Print(R); end
    return;
end

% ---- check
t = tic;
K = GRIT_Check(M, N, opts);
if opts.q_margin > 0
    K = GRIT_Band(M, N, K, opts);
end
R.time.check = toc(t);
R.check = K;
if K.feasible, R.verdict = 'FEASIBLE'; else, R.verdict = 'VIOLATED'; end

% ---- certificate
R.cert = [];
R.time.cert = 0;
if ~strcmpi(opts.cert.mode, 'off')
    C = GRIT_Certificate(M, N, opts);
    C = localShift(M, N, K, C);
    R.cert = C; R.time.cert = C.time;
end

% ---- repair
R.time.repair = 0;
if opts.repair.enable && ~K.feasible
    t = tic;
    [P, M2, N2, K2] = GRIT_Repair(M, N, K, opts);
    R.repair = P;
    R.time.repair = toc(t);
    if P.success || P.relaxed
        if P.success, R.verdict = 'REPAIRED'; else, R.verdict = 'RELAXED'; end
        R.initial = struct('check', K, 'cert', R.cert, 'ac', localAC(M, N, K));
        M = M2; N = N2; K = K2;
        R.check = K;
        if ~strcmpi(opts.cert.mode, 'off')
            C = GRIT_Certificate(M, N, opts);
            C = localShift(M, N, K, C);
            R.cert = C; R.time.cert = R.time.cert + C.time;
        end
    end
end

% ---- price information
R.time.price = 0;
if opts.price.enable
    t = tic;
    R.price = GRIT_Price(M, N, opts);
    R.time.price = toc(t);
end

R.dc = localDC(M);
R.ac = localAC(M, N, K);
R.violations = localViolTable(M, K);
R.time.total = toc(tAll) - M.time_dc;      % the DC-OPF is the input of the check, it is timed separately

% ---- comparison with MATPOWER (comparison only)
R.compare = [];
if opts.compare.pf || opts.compare.opf
    R.compare = GRIT_Compare(M, N, K, opts);
end
R.model = M;
R.solution = struct('V', N.V, 's', N.s, 'atlim', N.atlim, 'pv', N.pv, 'pq', N.pq, 'rq', N.rq);
if opts.verbose > 0, GRIT_Print(R); end
end

% -------------------------------------------------------------------------
function D = localDC(M)
D.source = M.dc.source;
D.cost = M.dc.cost;
D.pg = M.dc.pg;                 % MW, rows of the input generator table
D.va = M.dc.va;                 % degree, rows of the input bus table
D.pf = M.dc.pf;                 % MW, rows of the input branch table
D.lmp = M.dc.lmp;
D.loss_estimate = M.loss_dc * M.baseMVA;
end

function A = localAC(M, N, K)
base = M.baseMVA;
A.bus = [M.map.bus, K.Vm, K.Va, M.vmin, M.vmax];
A.bus_cols = {'bus', 'Vm (pu)', 'Va (deg)', 'Vmin', 'Vmax'};
A.branch = [M.map.branch, M.map.bus(M.fbus), M.map.bus(M.tbus), real(K.Sf), imag(K.Sf), ...
    real(K.St), imag(K.St), K.loading, K.rate, K.loading_pct, M.dc.pf(M.map.branch)];
A.branch_cols = {'row', 'from', 'to', 'Pf (MW)', 'Qf (Mvar)', 'Pt (MW)', 'Qt (Mvar)', ...
    ['loading (' K.flow_unit ')'], 'rating', 'percent', 'DC Pf (MW)'};
A.gen = [M.map.gen, M.map.bus(M.gbus), K.Pg_dc, K.Pg, K.Qg, M.gqmin * base, M.gqmax * base, N.atlim(M.gbus)];
A.gen_cols = {'row', 'bus', 'Pg DC (MW)', 'Pg AC (MW)', 'Qg (Mvar)', 'Qmin', 'Qmax', 'at Q limit'};
A.loss = K.loss;
A.flow_error = real(K.Sf) - M.dc.pf(M.map.branch);        % AC minus DC active flow (MW)
A.max_flow_error = max(abs(A.flow_error));
A.cost = NaN;
if isfield(M.mpc, 'gencost') && ~isempty(M.mpc.gencost)
    pg = M.dc.pg; pg(M.map.gen) = K.Pg;
    c = totcost(M.mpc.gencost(1:size(M.mpc.gen, 1), :), pg);
    A.cost = sum(c(M.map.gen));
end
end

function T = localViolTable(M, K)
n = K.n_viol;
T = cell(n, 6);
for r = 1:n
    kind = K.viol(r, 1); i = K.viol(r, 2);
    switch K.kind_element{kind}
        case 'bus'
            lab = sprintf('bus %d', M.map.bus(i));
        case 'branch'
            lab = sprintf('branch %d (%d-%d)', M.map.branch(i), M.map.bus(M.fbus(i)), M.map.bus(M.tbus(i)));
        otherwise
            lab = sprintf('generator %d (bus %d)', M.map.gen(i), M.map.bus(M.gbus(i)));
    end
    T(r, :) = {K.kind_names{kind}, lab, K.viol(r, 3), K.viol(r, 4), K.viol(r, 5), K.kind_units{kind}};
end
end

function C = localShift(M, N, K, C)
% Largest change of each checked quantity between the computed point and
% the exact solution, from the certified distance rho_minus.
C.undecided = NaN; C.shift_v = NaN; C.shift_flow = NaN; C.shift_q = NaN;
if ~C.certified, return; end
base = M.baseMVA; V = N.V; rho = 1.01 * C.rho_minus;
C.shift_v = sqrt(2) * rho;
kf = sqrt(2) * (abs(M.Yf * V) + abs(V(M.fbus)) .* full(sum(abs(M.Yf), 2)));
kt = sqrt(2) * (abs(M.Yt * V) + abs(V(M.tbus)) .* full(sum(abs(M.Yt), 2)));
kb = sqrt(2) * (abs(M.Ybus * V) + abs(V) .* full(sum(abs(M.Ybus), 2)));
sf = max(kf, kt) * rho * base;
sq = kb * rho * base;
C.shift_flow = max(sf); C.shift_q = max(sq(M.isgen)); C.shift_p = rho * base;
% only computed quantities are counted: set points and dispatched values are data
calcV = true(M.nb, 1); calcV([N.pv; N.ref(isempty(N.rq))]) = false;
calcQ = M.isgen & N.atlim == 0;
calcP = M.alpha > 0;
und = nnz(abs(K.margin_v(calcV)) <= C.shift_v) + nnz(abs(K.margin_flow) <= sf) + ...
      nnz(abs(K.margin_qmax(calcQ)) <= sq(calcQ)) + nnz(abs(K.margin_qmin(calcQ)) <= sq(calcQ)) + ...
      nnz(abs(K.margin_pmax(calcP)) <= C.shift_p) + nnz(abs(K.margin_pmin(calcP)) <= C.shift_p);
C.undecided = und;      % limits whose margin is inside the possible change
end

function D = localDiagnose(M)
% Facts about the DC solution that help to read a failed AC solution.
dth = abs(M.va_dc(M.fbus) - M.va_dc(M.tbus)) * 180 / pi;
D.max_dc_angle_diff = max(dth);
big = find(dth > 60);
[~, o] = sort(dth(big), 'descend'); big = big(o);
D.wide_branches = [M.map.branch(big), M.map.bus(M.fbus(big)), M.map.bus(M.tbus(big)), dth(big), M.rate(big) * M.baseMVA];
D.wide_cols = {'row', 'from', 'to', 'DC angle difference (deg)', 'rating'};
D.loss_estimate = M.loss_dc * M.baseMVA;
D.headroom = sum(max(M.gpmax - M.Pg, 0)) * M.baseMVA;
end
