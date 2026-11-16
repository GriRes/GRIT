function ok = GRIT_TestGUISmoke()
%GRIT_TESTGUISMOKE  Smoke test of the graphical interface (window stays hidden).
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
n = 0; nf = 0;
H = GRIT_GUI('hidden');
closer = onCleanup(@() close(H.fig)); %#ok<NASGU>
step('window is created', ishandle(H.fig));
H.setCase('case14'); H.run(); R = H.result();
step('case14 runs from the interface', ~isempty(R) && any(strcmp(R.verdict, {'FEASIBLE', 'VIOLATED', 'REPAIRED', 'RELAXED'})));
for k = 1:5
    H.view(k); drawnow;
    step(sprintf('plot %d is drawn', k), ~isempty(get(H.handles.ax, 'Children')));
end
H.batch(); B = H.batchResult();
step('N-1 batch runs from the interface', ~isempty(B) && size(B.table, 1) > 0);
H.view(6); drawnow;
step('batch plot is drawn', ~isempty(get(H.handles.ax, 'Children')));
for k = 1:4
    H.menu(k); drawnow;
    step(sprintf('menu %d opens', k), strcmp(get(H.menuPanels{k}, 'Visible'), 'on'));
end
H.menu(4); drawnow;
H.setAdvanced(struct('repair_max_rounds', 3, 'repair_controls', 'p')); H.setCase('case30'); H.run(); R = H.result();
step('advanced settings reach the run', R.opts.repair.max_rounds == 3 && strcmp(R.opts.repair.controls, 'p'));
H.setAdvanced(struct());
f = [tempname '.md']; H.report(f); d = dir(f);
step('report is written from the interface', ~isempty(d) && d.bytes > 300); delete(f);
set(H.handles.scale, 'String', 'abc'); H.run();
c = H.console(); last = c{end};
step('a wrong number in a field gives a readable message', ~isempty(strfind(last, 'Load scaling'))); %#ok<STREMP>
set(H.handles.scale, 'String', '1.0'); H.setCase('no_such_case'); H.run();
c = H.console(); last = c{end};
step('a wrong case name gives a readable message', ~isempty(strfind(last, 'Cannot load'))); %#ok<STREMP>
fprintf('GRIT GUI smoke test: %d of %d steps passed.\n', n - nf, n);
ok = nf == 0;
    function step(msg, cond)
        n = n + 1;
        if cond
            fprintf('  pass  %s\n', msg);
        else
            nf = nf + 1; fprintf('  FAIL  %s\n', msg);
            cc = H.console(); fprintf('        console: %s\n', cc{max(1, end-2):end});
        end
    end
end
