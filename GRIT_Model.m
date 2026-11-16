function M = GRIT_Model(input, opts)
%GRIT_MODEL  Load a case, obtain the DC dispatch and build the network model.
%   M = GRIT_MODEL(INPUT, OPTS) accepts a MATPOWER case name, a case file
%   name or a case structure. With OPTS.dispatch.source = 'dcopf' the
%   function runs the DC-OPF of MATPOWER. With 'case' it takes the active
%   power values of the case as the dispatch and runs a DC power flow to
%   get the DC angles.
%
%   M holds internally numbered data (consecutive buses, in-service
%   elements only) and index maps back to the rows of the input case.
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

[PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM, VA, ...
    BASE_KV, ZONE, VMAX, VMIN, LAM_P] = idx_bus; %#ok<ASGLU>
[GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN] = idx_gen; %#ok<ASGLU>
[F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE_A, RATE_B, RATE_C, TAP, SHIFT, ...
    BR_STATUS, PF, QF, PT, QT, MU_SF, MU_ST, ANGMIN, ANGMAX] = idx_brch; %#ok<ASGLU>

% ---- load and validate the case
if ischar(input)
    try
        mpc = loadcase(input);
    catch err
        error('GRIT:input', 'Cannot load the case "%s". %s', input, err.message);
    end
    M.name = input;
elseif isstruct(input)
    need = {'baseMVA', 'bus', 'gen', 'branch'};
    for k = 1:numel(need)
        if ~isfield(input, need{k})
            error('GRIT:input', 'The case structure has no field "%s".', need{k});
        end
    end
    mpc = loadcase(input);
    M.name = 'case structure';
else
    error('GRIT:input', 'The input must be a case name or a MATPOWER case structure.');
end
if isempty(mpc.bus) || isempty(mpc.gen) || isempty(mpc.branch)
    error('GRIT:input', 'The case has an empty bus, generator or branch table.');
end
if size(mpc.branch, 2) < ANGMAX
    mpc.branch(:, size(mpc.branch, 2)+1:ANGMAX) = 0;
    mpc.branch(:, ANGMIN) = -360;
    mpc.branch(:, ANGMAX) = 360;
end
if any(~isfinite(mpc.bus(:, PD))) || any(~isfinite(mpc.bus(:, QD)))
    error('GRIT:input', 'The bus table holds a load that is not a finite number.');
end
if isfield(mpc, 'dcline') && ~isempty(mpc.dcline) && any(mpc.dcline(:, 3) > 0)
    warning('GRIT:dcline', 'DC lines of the case are not modeled by GRIT %s.', GRIT_Version());
end

% ---- load scaling and limit overrides
sc = opts.dispatch.load_scale;
if ~isnumeric(sc) || ~isscalar(sc) || ~isfinite(sc) || sc <= 0
    error('GRIT:input', 'Option dispatch.load_scale must be a positive number.');
end
mpc.bus(:, [PD QD]) = mpc.bus(:, [PD QD]) * sc;
if ~isempty(opts.limits.v_min)
    localScalar(opts.limits.v_min, 'limits.v_min');
    mpc.bus(:, VMIN) = opts.limits.v_min;
end
if ~isempty(opts.limits.v_max)
    localScalar(opts.limits.v_max, 'limits.v_max');
    mpc.bus(:, VMAX) = opts.limits.v_max;
end
if any(mpc.bus(:, VMIN) > mpc.bus(:, VMAX))
    error('GRIT:input', 'A bus has a lower voltage limit above its upper limit.');
end
rc = find(strcmpi(opts.limits.rate, {'A', 'B', 'C'}));
if isempty(rc)
    error('GRIT:input', 'Option limits.rate must be ''A'', ''B'' or ''C''.');
end
rcol = RATE_A + rc - 1;
localScalar(opts.limits.rate_scale, 'limits.rate_scale');

% ---- DC dispatch
mpopt = mpoption('verbose', 0, 'out.all', 0);
tStart = tic;
switch lower(opts.dispatch.source)
    case 'dcopf'
        if ~isfield(mpc, 'gencost') || isempty(mpc.gencost)
            error('GRIT:input', ['The case has no generator cost data, so the DC-OPF cannot run. ' ...
                'Set dispatch.source to ''case'' to use the active power values of the case as the dispatch.']);
        end
        mdc = mpc;
        mdc.branch(:, RATE_A) = mpc.branch(:, rcol) * opts.limits.rate_scale;
        rdc = rundcopf(mdc, mpopt);
        if ~rdc.success
            error('GRIT:dcopf', 'The DC-OPF did not converge. No DC dispatch is available.');
        end
        M.dc.cost = rdc.f;
        M.dc.lmp = rdc.bus(:, LAM_P);
        M.dc.mu_sf = rdc.branch(:, MU_SF);
        M.dc.mu_st = rdc.branch(:, MU_ST);
    case 'case'
        rdc = rundcpf(mpc, mpopt);
        if ~rdc.success
            error('GRIT:dcpf', 'The DC power flow of the given dispatch failed.');
        end
        M.dc.cost = NaN;
        if isfield(mpc, 'gencost') && ~isempty(mpc.gencost)
            ng0 = size(mpc.gen, 1);
            on0 = mpc.gen(:, GEN_STATUS) > 0;
            c = totcost(mpc.gencost(1:ng0, :), rdc.gen(:, PG));
            M.dc.cost = sum(c(on0));
        end
        M.dc.lmp = nan(size(mpc.bus, 1), 1);
        M.dc.mu_sf = zeros(size(mpc.branch, 1), 1);
        M.dc.mu_st = zeros(size(mpc.branch, 1), 1);
    otherwise
        error('GRIT:input', 'Option dispatch.source must be ''dcopf'' or ''case''.');
end
M.time_dc = toc(tStart);
M.dc.pg = rdc.gen(:, PG);
M.dc.va = rdc.bus(:, VA);
M.dc.pf = rdc.branch(:, PF);
M.dc.source = lower(opts.dispatch.source);

% ---- internal numbering
mpc.gen(:, PG) = rdc.gen(:, PG);
mpc.bus(:, VA) = rdc.bus(:, VA);
mi = ext2int(mpc);
nb = size(mi.bus, 1); ng = size(mi.gen, 1); nl = size(mi.branch, 1);
if nb < 2 || ng < 1 || nl < 1
    error('GRIT:input', 'After removal of out-of-service elements the network is empty.');
end
[ref, pv, pq] = bustypes(mi.bus, mi.gen);
if numel(ref) ~= 1
    error('GRIT:input', 'The network needs exactly one reference bus. It has %d.', numel(ref));
end
adj = sparse([mi.branch(:, F_BUS); mi.branch(:, T_BUS)], [mi.branch(:, T_BUS); mi.branch(:, F_BUS)], 1, nb, nb);
if ~localConnected(adj, ref)
    error('GRIT:input', ['The in-service network is not connected. GRIT %s handles one ' ...
        'connected network with one reference bus.'], GRIT_Version());
end

o = mi.order;
M.map.bus = o.bus.i2e(:);                                   % external bus number of each internal bus
M.map.gen = o.gen.status.on(o.gen.i2e); M.map.gen = M.map.gen(:);   % input gen row of each internal gen
M.map.branch = o.branch.status.on(:);                       % input branch row of each internal branch
M.n_ext = [size(mpc.bus, 1), size(mpc.gen, 1), size(mpc.branch, 1)];

M.mpc = mpc;            % input case with scaled loads and the DC dispatch (external numbering)
M.mi = mi;              % internal case
M.baseMVA = mi.baseMVA;
M.nb = nb; M.ng = ng; M.nl = nl;
M.ref = ref; M.pv = pv(:); M.pq = pq(:);
[M.Ybus, M.Yf, M.Yt] = makeYbus(mi.baseMVA, mi.bus, mi.branch);
M.fbus = mi.branch(:, F_BUS); M.tbus = mi.branch(:, T_BUS);

% generator data collected by bus
gbus = mi.gen(:, GEN_BUS);
M.gbus = gbus;
Cg = sparse(gbus, (1:ng)', 1, nb, ng);
M.Cg = Cg;
M.Pg = mi.gen(:, PG) / M.baseMVA;                           % DC dispatch (pu)
M.Pd = mi.bus(:, PD) / M.baseMVA;
M.Qd = mi.bus(:, QD) / M.baseMVA;
qmax = mi.gen(:, QMAX) / M.baseMVA; qmin = mi.gen(:, QMIN) / M.baseMVA;
qmax(mi.gen(:, QMAX) >= 9999) = Inf;                        % 9999 Mvar and above means no limit
qmin(mi.gen(:, QMIN) <= -9999) = -Inf;
if any(qmin > qmax)
    error('GRIT:input', 'A generator has a lower reactive limit above its upper limit.');
end
M.gqmax = qmax; M.gqmin = qmin;
M.bqmax = full(Cg * localFin(qmax)); M.bqmax(Cg * double(isinf(qmax)) > 0) = Inf;
M.bqmin = full(Cg * localFin(qmin)); M.bqmin(Cg * double(isinf(qmin)) > 0) = -Inf;
M.gpmax = mi.gen(:, PMAX) / M.baseMVA; M.gpmin = mi.gen(:, PMIN) / M.baseMVA;
M.isgen = full(sum(Cg, 2)) > 0;
Vset = ones(nb, 1);
Vset(gbus) = mi.gen(:, VG);
if any(Vset(M.isgen) <= 0)
    error('GRIT:input', 'A generator has a voltage set point that is not positive.');
end
M.Vset = Vset;
M.Vcase = mi.bus(:, VM);
M.vmin = mi.bus(:, VMIN); M.vmax = mi.bus(:, VMAX);
M.rate = mi.branch(:, rcol) * opts.limits.rate_scale / M.baseMVA;   % pu, 0 means no limit
M.angmin = mi.branch(:, ANGMIN); M.angmax = mi.branch(:, ANGMAX);
M.va_dc = mi.bus(:, VA) * pi / 180;
% participation of each generator in the active power losses
switch lower(opts.slack.mode)
    case 'headroom'
        w = max(M.gpmax - M.Pg, 0);
        if sum(w) < 1e-9, w = max(M.gpmax, 0); end
    case 'pmax'
        w = max(M.gpmax, 0);
    case 'single'
        w = double(gbus == ref);
        w = w .* (cumsum(w) == 1);          % first unit at the reference bus
    otherwise
        error('GRIT:input', 'Option slack.mode must be ''headroom'', ''pmax'' or ''single''.');
end
if sum(w) <= 0
    w = double(gbus == ref);
end
M.alpha = w / sum(w);
M.abus = full(Cg * M.alpha);
% loss estimate from the DC flows, used as the start value of the loss variable
pfdc = M.dc.pf(M.map.branch) / M.baseMVA;
M.loss_dc = sum(mi.branch(:, BR_R) .* pfdc.^2);
% specified complex injection: DC dispatch, loads, no generator Q yet
M.Sbus = Cg * M.Pg - M.Pd - 1j * M.Qd;
end

function localScalar(v, name)
if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v) || v <= 0
    error('GRIT:input', 'Option %s must be a positive number.', name);
end
end

function v = localFin(v)
v(isinf(v)) = 0;
end

function ok = localConnected(adj, start)
nb = size(adj, 1);
seen = false(nb, 1); seen(start) = true;
front = start;
while ~isempty(front)
    [nxt, ~] = find(adj(:, front));
    nxt = unique(nxt);
    nxt = nxt(~seen(nxt));
    seen(nxt) = true;
    front = nxt;
end
ok = all(seen);
end
