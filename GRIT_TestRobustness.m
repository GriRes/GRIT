function ok = GRIT_TestRobustness()
%GRIT_TESTROBUSTNESS  Robustness tests of GRIT: wrong inputs and random scenarios.
%   A wrong input must end with an error whose identifier starts with
%   'GRIT:'. A random scenario must end with one of the five verdicts.
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
T = struct('n', 0, 'fail', 0);
base = loadcase('case9');
bad = {};
bad{end+1} = {'a case name that does not exist', @() GRIT_Run('no_such_case_xyz', 'verbose', 0)};
bad{end+1} = {'a number as input', @() GRIT_Run(42, 'verbose', 0)};
bad{end+1} = {'a structure without a branch table', @() GRIT_Run(rmfield(base, 'branch'), 'verbose', 0)};
m = base; m.bus = zeros(0, 13);
bad{end+1} = {'an empty bus table', @() GRIT_Run(m, 'verbose', 0)};
bad{end+1} = {'a negative load scaling', @() GRIT_Run('case9', 'verbose', 0, 'dispatch.load_scale', -1)};
bad{end+1} = {'a load scaling that is not a number', @() GRIT_Run('case9', 'verbose', 0, 'dispatch.load_scale', 'abc')};
bad{end+1} = {'voltage minimum above maximum', @() GRIT_Run('case9', 'verbose', 0, 'limits.v_min', 1.2, 'limits.v_max', 0.9)};
bad{end+1} = {'an unknown option', @() GRIT_Run('case9', 'verbose', 0, 'no.such.option', 1)};
bad{end+1} = {'an unknown option group', @() GRIT_Run('case9', struct('nothing', 1))};
bad{end+1} = {'an odd number of option arguments', @() GRIT_Run('case9', 'verbose')};
bad{end+1} = {'a wrong branch limit type', @() GRIT_Run('case9', 'verbose', 0, 'limits.flow', 'X')};
bad{end+1} = {'a wrong rating column', @() GRIT_Run('case9', 'verbose', 0, 'limits.rate', 'D')};
bad{end+1} = {'a wrong loss sharing mode', @() GRIT_Run('case9', 'verbose', 0, 'slack.mode', 'none')};
bad{end+1} = {'a wrong dispatch source', @() GRIT_Run('case9', 'verbose', 0, 'dispatch.source', 'acopf')};
bad{end+1} = {'a wrong certificate mode', @() GRIT_Run('case9', 'verbose', 0, 'cert.mode', 'maybe')};
bad{end+1} = {'a wrong repair control set', @() GRIT_Run('case14', 'verbose', 0, 'repair.enable', true, 'repair.controls', 'q')};
bad{end+1} = {'a wrong start point name', @() GRIT_Run('case9', 'verbose', 0, 'newton.vm_init', 'warm')};
bad{end+1} = {'no cost data with the DC-OPF', @() GRIT_Run('case4gs', 'verbose', 0)};
m = base; m.bus(5, 3) = NaN;
bad{end+1} = {'a load that is not a number', @() GRIT_Run(m, 'verbose', 0)};
m = base; m.bus(2, 2) = 3;
bad{end+1} = {'two reference buses', @() GRIT_Run(m, 'verbose', 0)};
m = base; m.branch([4 9], 11) = 0; m.branch([5 6], 11) = 0;
bad{end+1} = {'a network that is not connected', @() GRIT_Run(m, 'verbose', 0, 'dispatch.source', 'case')};
m = base; m.gen(2, 4) = -50; m.gen(2, 5) = 50;
bad{end+1} = {'a reactive lower limit above the upper limit', @() GRIT_Run(m, 'verbose', 0)};
m = base; m.gen(2, 6) = 0;
bad{end+1} = {'a voltage set point of zero', @() GRIT_Run(m, 'verbose', 0)};
m = base; m.bus(:, 3) = m.bus(:, 3) * 20;
bad{end+1} = {'a load that the DC-OPF cannot serve', @() GRIT_Run(m, 'verbose', 0)};
bad{end+1} = {'a wrong batch mode', @() GRIT_Batch('case9', 'n-2', [], 'verbose', 0)};
bad{end+1} = {'a batch branch that does not exist', @() GRIT_Batch('case9', 'n-1', 99, 'verbose', 0)};
bad{end+1} = {'a negative load factor in a batch', @() GRIT_Batch('case9', 'load', [1 -1], 'verbose', 0)};
bad{end+1} = {'a report without a result', @() GRIT_Report(struct('x', 1))};
for k = 1:numel(bad)
    try
        ws = warning('off', 'all'); bad{k}{2}(); warning(ws);
        T = check(T, false, ['error expected for ' bad{k}{1}]);
    catch err
        warning(ws);
        T = check(T, strncmp(err.identifier, 'GRIT:', 5), sprintf('%s is refused (%s)', bad{k}{1}, err.identifier));
    end
end
% inputs that must work
good = {};
good{end+1} = {'a case structure', @() GRIT_Run(base, 'verbose', 0)};
good{end+1} = {'a case without cost data and the dispatch of the case', @() GRIT_Run('case4gs', 'verbose', 0, 'dispatch.source', 'case')};
good{end+1} = {'an option structure', @() GRIT_Run('case14', struct('verbose', 0, 'repair', struct('enable', true)))};
good{end+1} = {'no reactive limits and losses at the reference bus', @() GRIT_Run('case30', 'verbose', 0, 'newton.enforce_q', false, 'slack.mode', 'single')};
good{end+1} = {'branch limits on MW', @() GRIT_Run('case30', 'verbose', 0, 'limits.flow', 'P', 'repair.enable', true)};
good{end+1} = {'branch limits on current', @() GRIT_Run('case30', 'verbose', 0, 'limits.flow', 'I', 'repair.enable', true)};
good{end+1} = {'repair with active power only', @() GRIT_Run('case30', 'verbose', 0, 'repair.enable', true, 'repair.controls', 'p')};
good{end+1} = {'angle limits, estimate mode, comparison with MATPOWER', @() GRIT_Run('case39', 'verbose', 0, 'limits.angle', true, 'cert.mode', 'estimate', 'compare.pf', true, 'compare.opf', true)};
m = loadcase('case30'); m.gen(3, 8) = 0; m.branch(7, 11) = 0;
good{end+1} = {'a unit and a branch out of service', @() GRIT_Run(m, 'verbose', 0, 'repair.enable', true)};
m = loadcase('case30'); m.branch(:, 6) = 0;
good{end+1} = {'a case without branch ratings', @() GRIT_Run(m, 'verbose', 0, 'repair.enable', true)};
verd = {'FEASIBLE', 'VIOLATED', 'REPAIRED', 'RELAXED', 'NO_SOLUTION'};
for k = 1:numel(good)
    try
        ws = warning('off', 'all'); R = good{k}{2}(); warning(ws);
        T = check(T, any(strcmp(R.verdict, verd)), sprintf('%s runs (%s)', good{k}{1}, R.verdict));
    catch err
        warning(ws);
        T = check(T, false, sprintf('%s: %s', good{k}{1}, err.message));
    end
end
% random scenarios
rand('seed', 7); %#ok<RAND>
cs = {'case14', 'case30', 'case57', 'case118'};
nrun = 0; nbad = 0; cnt = zeros(1, 5); nin = 0;
for k = 1:80
    m = loadcase(cs{1 + mod(k, 4)});
    m.bus(:, 3:4) = m.bus(:, 3:4) .* (0.5 + rand(size(m.bus, 1), 2)) * (0.6 + 0.8 * rand);
    nl = size(m.branch, 1); out = randperm(nl, mod(k, 3));
    m.branch(out, 11) = 0;
    try
        ws = warning('off', 'all');
        R = GRIT_Run(m, 'verbose', 0, 'repair.enable', mod(k, 2) == 0);
        warning(ws);
        i = find(strcmp(R.verdict, verd));
        if isempty(i), nbad = nbad + 1; else, cnt(i) = cnt(i) + 1; end
        if ~isempty(R.check) && any(strcmp(R.verdict, {'FEASIBLE', 'REPAIRED'})) && R.check.n_viol > 0, nbad = nbad + 1; end
        nrun = nrun + 1;
    catch err
        warning(ws);
        if strncmp(err.identifier, 'GRIT:', 5), nin = nin + 1; else, nbad = nbad + 1; fprintf('        scenario %d: %s\n', k, err.message); end
    end
end
T = check(T, nbad == 0, sprintf('80 random scenarios: %d verdicts %s, %d refused inputs, %d unexpected errors', nrun, mat2str(cnt), nin, nbad));
fprintf('GRIT robustness: %d of %d tests passed.\n', T.n - T.fail, T.n);
ok = T.fail == 0;
end

function T = check(T, cond, msg)
T.n = T.n + 1;
if cond, fprintf('  pass  %s\n', msg); else, T.fail = T.fail + 1; fprintf('  FAIL  %s\n', msg); end
end
