function ok = GRIT_TestSuite(big)
%GRIT_TESTSUITE  Run all tests of GRIT.
%   OK = GRIT_TESTSUITE() runs the regression, robustness and interface
%   tests. OK = GRIT_TESTSUITE(true) adds the time comparison with AC-OPF
%   on two large cases.
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
if nargin < 1, big = false; end
a = GRIT_TestRegression(big);
b = GRIT_TestRobustness();
c = true;
if usejava('awt') || ~exist('OCTAVE_VERSION', 'builtin')
    c = GRIT_TestGUISmoke();
end
ok = a && b && c;
if ok, fprintf('All GRIT tests passed.\n'); else, fprintf('Some GRIT tests failed.\n'); end
end
