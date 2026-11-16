function opts = GRIT_Config(varargin)
%GRIT_CONFIG  Default options of GRIT.
%   OPTS = GRIT_CONFIG() returns the default option structure.
%   OPTS = GRIT_CONFIG(USER) overlays the fields of the structure USER on
%   the defaults. Nested fields are merged. Unknown fields raise an error.
%   OPTS = GRIT_CONFIG('name', value, ...) sets fields by dotted name,
%   for example GRIT_CONFIG('repair.enable', true).
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

opts = struct();

% Input and dispatch
opts.dispatch.source      = 'dcopf';   % 'dcopf' (GRIT runs the DC-OPF) or 'case' (PG of the case is the dispatch)
opts.dispatch.load_scale  = 1.0;       % uniform scaling of all loads (P and Q)

% Sharing of the active power losses among generators
opts.slack.mode           = 'headroom';% 'headroom' (share by PMAX minus dispatch), 'pmax' (share by PMAX) or 'single' (reference bus only)

% AC solution from the DC point
opts.newton.tol           = 1e-8;      % convergence tolerance on the largest bus mismatch (pu)
opts.newton.max_it        = 40;        % limit on Newton iterations (all Q-limit rounds together)
opts.newton.enforce_q     = true;      % generators at a Q limit stop holding their voltage set point
opts.newton.q_tol         = 1e-6;      % tolerance on Q limits (pu)
opts.newton.v_tol         = 1e-6;      % tolerance on set-point comparison when a unit leaves its Q limit (pu)
opts.newton.q_rounds      = 20;        % limit on Q-limit switching rounds
opts.newton.vm_init       = 'auto';    % magnitude at load buses in the start point: 'flat', 'case' or 'auto'
opts.newton.step_min      = 1/64;      % smallest damping factor of a Newton step
opts.newton.continuation  = true;      % when Newton fails, scale the injections up from zero to locate the failure
opts.newton.cont_max_fact = 60;        % limit on Jacobian factorizations spent in the continuation

% Operating limits used by the check
opts.limits.v_min         = [];        % scalar (pu) overrides VMIN of the case, [] keeps the case values
opts.limits.v_max         = [];        % scalar (pu) overrides VMAX of the case, [] keeps the case values
opts.limits.flow          = 'S';       % branch limit on 'S' (MVA), 'P' (MW) or 'I' (current, MVA at 1 pu voltage)
opts.limits.rate          = 'A';       % rating column: 'A', 'B' or 'C'
opts.limits.rate_scale    = 1.0;       % scaling of all branch ratings
opts.limits.angle         = false;     % check branch angle difference limits ANGMIN, ANGMAX

% Tolerances of the check
opts.tol.v                = 1e-5;      % voltage magnitude (pu)
opts.tol.flow             = 1e-3;      % branch loading (MVA or MW)
opts.tol.q                = 1e-3;      % reactive power (Mvar)
opts.tol.p                = 1e-3;      % active power (MW)
opts.tol.angle            = 1e-4;      % angle difference (degree)

% Reactive power uncertainty at load buses
opts.q_margin             = 0;         % relative uncertainty of reactive load, 0.05 means +/- 5 percent

% A posteriori certificate
opts.cert.mode            = 'auto';    % 'auto', 'exact', 'estimate' or 'off'
opts.cert.exact_max_bus   = 1500;      % 'auto' uses the exact constant up to this number of buses
opts.cert.block           = 1000;      % number of right-hand sides solved together

% Repair
opts.repair.enable        = false;     % search a nearby dispatch that satisfies all checked limits
opts.repair.controls      = 'pv';      % 'p' (active power only) or 'pv' (active power and voltage set points)
opts.repair.max_rounds    = 12;        % limit on linear program rounds
opts.repair.ramp_pct      = 1.00;      % largest active power change of a unit, fraction of PMAX (1 means unit limits only)
opts.repair.dv_max        = 0.05;      % largest change of a voltage set point (pu)
opts.repair.step_p        = 0.10;      % trust region of active power per round, fraction of PMAX
opts.repair.step_v        = 0.02;      % trust region of a voltage set point per round (pu)
opts.repair.screen        = 0.05;      % limits closer than this relative margin enter the linear program
opts.repair.back_off      = 1e-3;      % relative tightening of limits inside the linear program
opts.repair.time_ratio    = 8;         % the repair stops after this multiple of the AC solution time
opts.repair.min_time      = 2;         % and never before this time (s)
opts.repair.w_v           = 0.1;       % weight of voltage set-point changes ($/MWh equivalent per 0.01 pu)

% Accepted relaxation of limits when the repair cannot satisfy all of them
opts.relax.v              = 0;         % voltage magnitude (pu), 0 means no relaxation
opts.relax.flow_pct       = 0;         % branch loading (percent of the rating), 0 means no relaxation

% Price information
opts.price.enable         = true;      % marginal loss factors and fixed-dispatch loss prices

% Comparison with MATPOWER (comparison only, never used by the analysis)
opts.compare.pf           = false;     % run MATPOWER AC power flow and report the difference
opts.compare.opf          = false;     % run MATPOWER AC-OPF and report cost and time

opts.verbose              = 1;         % 0 silent, 1 summary, 2 iteration log

if nargin == 0
    return;
end
if nargin == 1
    user = varargin{1};
    if isempty(user)
        return;
    end
    if ~isstruct(user)
        error('GRIT:input', 'GRIT_Config: the option argument must be a structure.');
    end
    opts = localMerge(opts, user, 'opts');
    return;
end
if mod(nargin, 2) ~= 0
    error('GRIT:input', 'GRIT_Config: name and value arguments must come in pairs.');
end
for k = 1:2:nargin
    name = varargin{k};
    if ~ischar(name)
        error('GRIT:input', 'GRIT_Config: option names must be character vectors.');
    end
    parts = regexp(name, '\.', 'split');
    opts = localSet(opts, parts, varargin{k+1}, name);
end
end

function base = localMerge(base, user, path)
names = fieldnames(user);
for k = 1:numel(names)
    f = names{k};
    if ~isfield(base, f)
        error('GRIT:input', 'Unknown option "%s.%s".', path, f);
    end
    if isstruct(base.(f))
        if ~isstruct(user.(f))
            error('GRIT:input', 'Option "%s.%s" must be a structure.', path, f);
        end
        base.(f) = localMerge(base.(f), user.(f), [path '.' f]);
    else
        base.(f) = user.(f);
    end
end
end

function s = localSet(s, parts, value, name)
f = parts{1};
if ~isfield(s, f)
    error('GRIT:input', 'Unknown option "%s".', name);
end
if numel(parts) == 1
    if isstruct(s.(f))
        error('GRIT:input', 'Option "%s" is a group, not a value.', name);
    end
    s.(f) = value;
else
    if ~isstruct(s.(f))
        error('GRIT:input', 'Unknown option "%s".', name);
    end
    s.(f) = localSet(s.(f), parts(2:end), value, name);
end
end
