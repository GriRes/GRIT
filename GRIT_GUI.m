function varargout = GRIT_GUI(varargin)
%GRIT_GUI  Graphical interface of GRIT.
%   GRIT_GUI opens the main window. Select a MATPOWER case, set the
%   options on the left and press Run (Ctrl+R). The menu bar gives access
%   to files, advanced settings, batch runs, plots and help. The cards show the verdict and
%   the main numbers. The plot, the table of violations and the console
%   show the details.
%
%   H = GRIT_GUI('hidden') creates the window without showing it and
%   returns handles and callbacks (used by the tests).
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

visible = 'on';
root = fileparts(mfilename('fullpath'));
addpath(root);                                  % GRIT stays usable when the current folder changes
if nargin > 0 && ischar(varargin{1}) && strcmpi(varargin{1}, 'hidden'), visible = 'off'; end

% ---- colours (same palette as GRIM)
C.bg = [0.067 0.075 0.102]; C.side = [0.086 0.098 0.133]; C.panel = [0.106 0.118 0.157];
C.card = [0.133 0.149 0.192]; C.input = [0.114 0.129 0.169]; C.accent = [0.000 0.545 0.647];
C.green = [0.118 0.573 0.345]; C.amber = [0.839 0.514 0.075]; C.red = [0.745 0.235 0.188];
C.blue = [0.149 0.447 0.776]; C.txt = [0.843 0.867 0.910]; C.dim = [0.431 0.471 0.537];
C.bdr = [0.176 0.196 0.255]; C.con = [0.043 0.051 0.071];
C.btnMain = [0.235 0.537 0.635]; C.btnGray = [0.141 0.173 0.220]; C.btnTxt = [0.902 0.929 0.965];
C.btnExit = [0.557 0.247 0.271];
C.menuBg = [0.094 0.106 0.145]; C.menuHov = [0.133 0.149 0.192]; C.menuTxt = [0.843 0.867 0.910];
C.menuTxtIdle = [0.65 0.68 0.74]; C.menuDrop = [0.114 0.129 0.169];
FN = 'Segoe UI';
if ismac, FN = 'Helvetica Neue'; end
TM = char(8482);

S.R = []; S.B = []; S.log = {}; S.adv = struct();
S.menuPanels = {}; S.menuBtns = {}; S.menuItems = {}; S.lastHover = [];
FW = 1240; FH = 830; SW = 300; MENU_H = 28; HH = 72;
scr = get(0, 'ScreenSize');
fig = figure('Name', ['GRIT' TM ' Version ' GRIT_Version() ' - Grid Realizability Inspection Tool'], 'NumberTitle', 'off', ...
    'MenuBar', 'none', 'ToolBar', 'none', 'Color', C.bg, 'Visible', visible, 'Resize', 'off', 'DockControls', 'off', ...
    'Position', [max(20, (scr(3) - FW) / 2), max(40, (scr(4) - FH) / 2), FW, FH], 'Tag', 'GRIT_GUI');

% ---- header with logo
menuY = FH - MENU_H; HDR_TOP = menuY;
uipanel(fig, 'Units', 'pixels', 'Position', [0 HDR_TOP-3 FW 3], 'BackgroundColor', C.accent, 'BorderType', 'none');
uipanel(fig, 'Units', 'pixels', 'Position', [20 HDR_TOP-HH-2 FW-40 1], 'BackgroundColor', C.bdr, 'BorderType', 'none');
txtX = 28;
logo52 = fullfile(root, 'Config', 'grires_logo_52.png');
if exist(logo52, 'file')
    try
        im = imread(logo52); ih = size(im, 1); iw = size(im, 2);
        axL = axes('Parent', fig, 'Units', 'pixels', 'Position', [22, HDR_TOP - HH + round((56 - ih) / 2) + 2, iw, ih], 'Visible', 'off');
        image('CData', im, 'Parent', axL);
        set(axL, 'XTick', [], 'YTick', [], 'XLim', [0.5 iw + 0.5], 'YLim', [0.5 ih + 0.5], 'YDir', 'reverse', 'Visible', 'off');
        txtX = 22 + iw + 6;
    catch
    end
end
uicontrol(fig, 'Style', 'text', 'String', 'GRIT', 'Position', [txtX HDR_TOP-HH+14 150 52], 'FontSize', 32, 'FontWeight', 'bold', ...
    'FontName', 'Consolas', 'ForegroundColor', C.accent, 'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');
uicontrol(fig, 'Style', 'text', 'String', TM, 'Position', [txtX+112 HDR_TOP-HH+40 30 22], 'FontSize', 14, 'FontWeight', 'bold', ...
    'FontName', FN, 'ForegroundColor', C.accent, 'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');
uicontrol(fig, 'Style', 'text', 'String', 'Grid Realizability Inspection Tool', 'Position', [txtX+160 HDR_TOP-HH+28 520 22], ...
    'FontSize', 13, 'FontWeight', 'bold', 'FontName', FN, 'ForegroundColor', C.txt, 'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');
uicontrol(fig, 'Style', 'text', 'String', ['Version ' GRIT_Version() '  |  AC Feasibility Check and Repair of DC Dispatch  |  A tool of the GriRes' TM ' Suite (Grid Resilience Suite)'], ...
    'Position', [txtX+160 HDR_TOP-HH+8 760 18], 'FontSize', 9, 'FontName', FN, 'ForegroundColor', C.dim, 'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');

% ---- sidebar
TOP = HDR_TOP - HH - 4;                          % top of the working area
SBH = 30;
uipanel(fig, 'Units', 'pixels', 'Position', [0 SBH SW TOP-SBH], 'BackgroundColor', C.side, 'BorderType', 'none');
x0 = 16; bw = SW - 32; y = TOP - 6;
hdr('CASE');
h.case = edt('case30');
h.browse = btn('Browse for a case file', @onBrowse, C.btnGray);
hdr('DISPATCH');
h.source = pop({'DC-OPF run by GRIT', 'Active power of the case'});
h.scale = lab('Load scaling', '1.0');
h.slack = pop({'Losses shared by headroom', 'Losses shared by PMAX', 'Losses at the reference bus'});
hdr('LIMITS');
h.vmin = lab('V minimum (pu, blank = case)', '');
h.vmax = lab('V maximum (pu, blank = case)', '');
h.flow = pop({'Branch limit on MVA', 'Branch limit on MW', 'Branch limit on current'});
h.rscale = lab('Rating scaling', '1.0');
hdr('ANALYSIS');
h.qlim = chk('Enforce generator reactive limits', 1);
h.cert = chk('Existence check of the AC solution', 1);
h.repair = chk('Repair violated limits', 1);
h.relv = lab('Voltage relaxation (pu)', '0');
h.relf = lab('Loading relaxation (percent)', '0');
h.opf = chk('Compare with AC-OPF (time and cost)', 0);
y = y - 8;
h.run = btn('Check and Repair', @onRun, C.btnMain); set(h.run, 'FontWeight', 'bold', 'FontSize', 11);
h.batch = btn('Batch: N-1 of all branches', @onBatch, C.btnGray);
h.report = btn('Write report', @onReport, C.btnGray);
h.exit = btn('Exit', @(~, ~) close(fig), C.btnExit);

% ---- status bar
uipanel(fig, 'Units', 'pixels', 'Position', [0 0 FW SBH], 'BackgroundColor', C.side, 'BorderType', 'none');
uipanel(fig, 'Units', 'pixels', 'Position', [0 SBH FW 1], 'BackgroundColor', C.bdr, 'BorderType', 'none');
h.status = uicontrol(fig, 'Style', 'text', 'String', 'Ready', 'Position', [14 5 FW-300 20], 'FontSize', 9, 'FontName', FN, ...
    'ForegroundColor', C.green, 'BackgroundColor', C.side, 'HorizontalAlignment', 'left');
mpTxt = 'MATPOWER: not found'; mpCol = C.amber;
if exist('loadcase', 'file'), mpTxt = 'MATPOWER: OK'; mpCol = C.green; end
uicontrol(fig, 'Style', 'text', 'String', mpTxt, 'Position', [FW-200 5 180 20], 'FontSize', 9, 'FontName', FN, ...
    'ForegroundColor', mpCol, 'BackgroundColor', C.side, 'HorizontalAlignment', 'right');

% ---- cards
MX = SW + 14; MW = FW - MX - 14;
names = {'VERDICT', 'VIOLATIONS', 'VOLTAGE (pu)', 'LARGEST LOADING', 'LOSSES', 'TIME'};
cw = (MW - 5 * 10) / 6; h.card = zeros(1, 6);
for k = 1:6
    px = MX + (k - 1) * (cw + 10);
    uipanel(fig, 'Units', 'pixels', 'Position', [px TOP-84 cw 72], 'BackgroundColor', C.card, 'BorderType', 'line', 'HighlightColor', C.bdr);
    uicontrol(fig, 'Style', 'text', 'String', names{k}, 'Position', [px+8 TOP-36 cw-16 16], 'FontSize', 8, 'FontName', FN, ...
        'ForegroundColor', C.dim, 'BackgroundColor', C.card, 'HorizontalAlignment', 'left');
    h.card(k) = uicontrol(fig, 'Style', 'text', 'String', '-', 'Position', [px+8 TOP-74 cw-16 30], 'FontSize', 14, 'FontWeight', 'bold', ...
        'FontName', FN, 'ForegroundColor', C.txt, 'BackgroundColor', C.card, 'HorizontalAlignment', 'left');
end

% ---- plot
h.view = uicontrol(fig, 'Style', 'popupmenu', 'String', {'Voltage profile', 'Branch loading', 'AC and DC active flow', ...
    'Dispatch: DC and AC', 'Marginal loss factors', 'Batch result'}, 'Position', [MX TOP-120 240 24], 'FontSize', 10, 'FontName', FN, ...
    'BackgroundColor', C.input, 'ForegroundColor', C.txt, 'Callback', @(~, ~) redraw());
axB = 300;
h.ax = axes('Parent', fig, 'Units', 'pixels', 'Position', [MX+50 axB MW-66 TOP-140-axB], 'Color', C.panel, ...
    'XColor', C.dim, 'YColor', C.dim, 'Box', 'on', 'FontSize', 9);
% ---- table of violations
uicontrol(fig, 'Style', 'text', 'String', 'VIOLATIONS', 'Position', [MX 254 200 16], 'FontSize', 8, 'FontName', FN, ...
    'ForegroundColor', C.dim, 'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');
h.table = uitable(fig, 'Position', [MX 134 MW 118], 'ColumnName', {'Kind', 'Element', 'Value', 'Limit', 'Excess', 'Unit'}, ...
    'ColumnWidth', {230, 270, 100, 100, 100, 108}, 'RowName', [], 'Data', cell(0, 6), 'FontSize', 9);
try, set(h.table, 'BackgroundColor', [C.card; C.panel], 'ForegroundColor', C.txt); catch, end %#ok<NOCOM>
% ---- console
h.con = uicontrol(fig, 'Style', 'listbox', 'String', {'GRIT is ready. Select a case and press Check and Repair (Ctrl+R).'}, 'Position', [MX SBH+8 MW 90], ...
    'FontName', 'Courier New', 'FontSize', 9, 'BackgroundColor', C.con, 'ForegroundColor', C.txt, 'Enable', 'inactive');

% ---- menu bar (same construction as GRIM)
uipanel(fig, 'Units', 'pixels', 'Position', [0 menuY FW MENU_H], 'BackgroundColor', C.menuBg, 'BorderType', 'none');
uipanel(fig, 'Units', 'pixels', 'Position', [0 menuY FW 1], 'BackgroundColor', [0.20 0.22 0.28], 'BorderType', 'none');
menuDefs = { ...
  'File', 50, {
    [char(9998) '  Open Case File...'],                    @onBrowse
    '---',                                                 []
    [char(9776) '  Write Report...'],                      @onReport
    [char(9632) '  Save Result (.mat)...'],                @onSave
    '---',                                                 []
    [char(10005) '  Exit                              Ctrl+Q'], @(~, ~) close(fig)
  }
  'Settings', 68, {
    [char(9881) '  Advanced Settings...'],                 @onSettings
    '---',                                                 []
    [char(9851) '  Reset All Settings'],                   @onReset
  }
  'Analysis', 74, {
    [char(9654) '  Check and Repair                Ctrl+R'], @onRun
    '---',                                                 []
    [char(9733) '  Batch: N-1 of All Branches'],           @onBatch
    [char(9733) '  Batch: Load Levels...'],                @onBatchLoad
    '---',                                                 []
    [char(9632) '  Voltage Profile'],                      @(~, ~) setView(1)
    [char(9632) '  Branch Loading'],                       @(~, ~) setView(2)
    [char(9632) '  AC and DC Active Flow'],                @(~, ~) setView(3)
    [char(9632) '  Dispatch: DC and AC'],                  @(~, ~) setView(4)
    [char(9632) '  Marginal Loss Factors'],                @(~, ~) setView(5)
  }
  'Help', 46, {
    [char(9432) '  User Guide'],                           @onGuide
    '---',                                                 []
    [char(9679) '  About GRIT'],                           @onAbout
    [char(10070) '  Citation Info'],                       @onCite
  }
};
mx = 8; ITEM_H = 26; SEP_H = 5; dropW = 310;
for mi = 1:size(menuDefs, 1)
    items = menuDefs{mi, 3}; mw = menuDefs{mi, 2};
    hBtn = uicontrol(fig, 'Style', 'text', 'String', menuDefs{mi, 1}, 'Position', [mx menuY+1 mw MENU_H-2], 'FontSize', 10, ...
        'FontName', FN, 'BackgroundColor', C.menuBg, 'ForegroundColor', C.menuTxtIdle, 'HorizontalAlignment', 'center', ...
        'Enable', 'inactive', 'ButtonDownFcn', @(~, ~) toggleMenu(mi));
    isSep = strcmp(items(:, 1), '---');
    dropH = nnz(~isSep) * ITEM_H + nnz(isSep) * SEP_H + 8;
    hDrop = uipanel(fig, 'Units', 'pixels', 'Position', [max(mx, 2) menuY-dropH dropW dropH], 'BackgroundColor', C.menuDrop, ...
        'BorderType', 'line', 'HighlightColor', [0.22 0.24 0.30], 'Visible', 'off');
    iy = dropH - 4; itemH = [];
    for ii = 1:size(items, 1)
        if isSep(ii)
            iy = iy - SEP_H;
            uipanel(hDrop, 'Units', 'pixels', 'Position', [12 iy+SEP_H/2-1 dropW-24 1], 'BackgroundColor', [0.20 0.22 0.28], 'BorderType', 'none');
        else
            iy = iy - ITEM_H; cbk = items{ii, 2};
            itemH(end+1) = uicontrol(hDrop, 'Style', 'text', 'String', ['  ' items{ii, 1}], 'Position', [4 iy dropW-8 ITEM_H], ...
                'FontSize', 10, 'FontName', FN, 'BackgroundColor', C.menuDrop, 'ForegroundColor', C.menuTxt, ...
                'HorizontalAlignment', 'left', 'Enable', 'inactive', 'ButtonDownFcn', @(src, evt) menuItemClick(cbk, src, evt)); %#ok<AGROW>
        end
    end
    S.menuBtns{mi} = hBtn; S.menuPanels{mi} = hDrop; S.menuItems{mi} = itemH;
    mx = mx + mw + 2;
end
set(fig, 'WindowButtonDownFcn', @onFigClick, 'WindowButtonMotionFcn', @onFigMotion, 'KeyPressFcn', @onKeyPress);

H.fig = fig; H.handles = h;
H.run = @() onRun([], []); H.batch = @() onBatch([], []); H.result = @getResult; H.batchResult = @getBatch;
H.setCase = @(c) set(h.case, 'String', c); H.report = @(f) writeReport(f); H.console = @() get(h.con, 'String');
H.view = @(k) setView(k); H.menu = @(k) toggleMenu(k); H.menuPanels = S.menuPanels;
H.setAdvanced = @setAdvanced;
H.open = @openDialog;
if nargout > 0, varargout{1} = H; end

% =========================================================================
    function toggleMenu(idx)
        vis = get(S.menuPanels{idx}, 'Visible');
        closeAllMenus();
        if strcmp(vis, 'off')
            uistack(S.menuPanels{idx}, 'top');
            set(S.menuPanels{idx}, 'Visible', 'on');
            set(S.menuBtns{idx}, 'BackgroundColor', C.menuHov, 'ForegroundColor', C.menuTxt, 'FontWeight', 'bold');
        end
    end
    function menuItemClick(cb, src, evt)
        closeAllMenus();
        if ~isempty(cb), cb(src, evt); end
    end
    function closeAllMenus()
        for q = 1:numel(S.menuPanels)
            set(S.menuPanels{q}, 'Visible', 'off');
            set(S.menuBtns{q}, 'BackgroundColor', C.menuBg, 'ForegroundColor', C.menuTxtIdle, 'FontWeight', 'normal');
        end
        if ~isempty(S.lastHover) && ishandle(S.lastHover)
            set(S.lastHover, 'BackgroundColor', C.menuDrop, 'ForegroundColor', C.menuTxt);
        end
        S.lastHover = [];
    end
    function onFigClick(~, ~)
        cp = get(fig, 'CurrentPoint');
        for q = 1:numel(S.menuPanels)
            if strcmp(get(S.menuPanels{q}, 'Visible'), 'on')
                p = get(S.menuPanels{q}, 'Position'); b = get(S.menuBtns{q}, 'Position');
                if inbox(cp, p) || inbox(cp, b), return; end
            end
        end
        closeAllMenus();
    end
    function onFigMotion(~, ~)
        cp = get(fig, 'CurrentPoint'); hit = [];
        for q = 1:numel(S.menuPanels)
            if strcmp(get(S.menuPanels{q}, 'Visible'), 'on')
                p = get(S.menuPanels{q}, 'Position');
                for it = S.menuItems{q}
                    ip = get(it, 'Position');
                    if inbox(cp, [p(1) + ip(1), p(2) + ip(2), ip(3), ip(4)]), hit = it; end
                end
            end
        end
        if isequal(hit, S.lastHover), return; end
        if ~isempty(S.lastHover) && ishandle(S.lastHover)
            set(S.lastHover, 'BackgroundColor', C.menuDrop, 'ForegroundColor', C.menuTxt);
        end
        if ~isempty(hit), set(hit, 'BackgroundColor', [0.18 0.20 0.26], 'ForegroundColor', [1 1 1]); end
        S.lastHover = hit;
    end
    function tf = inbox(cp, p)
        tf = cp(1) >= p(1) && cp(1) <= p(1) + p(3) && cp(2) >= p(2) && cp(2) <= p(2) + p(4);
    end
    function onKeyPress(~, evt)
        if ismember('control', evt.Modifier) || ismember('command', evt.Modifier)
            switch lower(evt.Key)
                case 'q', close(fig);
                case 'r', onRun([], []);
            end
        end
    end
    function openDialog(name)
        switch lower(name)
            case 'settings', onSettings([], []);
            case 'about', onAbout([], []);
            case 'guide', onGuide([], []);
            case 'cite', onCite([], []);
        end
    end
    function setAdvanced(a)
        S.adv = a;
    end
    function onReset(~, ~)
        S.adv = struct();
        set(h.source, 'Value', 1); set(h.slack, 'Value', 1); set(h.flow, 'Value', 1);
        set(h.scale, 'String', '1.0'); set(h.rscale, 'String', '1.0'); set(h.vmin, 'String', ''); set(h.vmax, 'String', '');
        set(h.relv, 'String', '0'); set(h.relf, 'String', '0');
        set(h.qlim, 'Value', 1); set(h.cert, 'Value', 1); set(h.repair, 'Value', 1); set(h.opf, 'Value', 0);
        say('All settings are back to their defaults.'); stat('Settings reset', C.green);
    end
    function onSettings(~, ~)
        d0 = GRIT_Config();
        fields = {'newton.tol', 'Newton tolerance (pu)'; 'newton.max_it', 'Newton iteration limit'; ...
            'q_margin', 'Reactive load uncertainty (0.05 = 5 percent)'; 'cert.exact_max_bus', 'Exact existence check up to this many buses'; ...
            'repair.max_rounds', 'Repair: limit on rounds'; 'repair.ramp_pct', 'Repair: largest change of a unit (fraction of PMAX)'; ...
            'repair.dv_max', 'Repair: largest set-point change (pu)'; 'repair.time_ratio', 'Repair: time limit (multiple of the AC solution time)'};
        nfld = size(fields, 1); DW = 560; DH = 110 + 34 * (nfld + 1);
        d = dialog('Name', 'Advanced Settings', 'Color', C.bg, 'Position', [scr(3)/2-DW/2 scr(4)/2-DH/2 DW DH]);
        he = zeros(nfld, 1);
        for q = 1:nfld
            yy = DH - 20 - 34 * q;
            uicontrol(d, 'Style', 'text', 'String', fields{q, 2}, 'Position', [20 yy DW-170 20], 'FontSize', 10, 'FontName', FN, ...
                'ForegroundColor', C.txt, 'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');
            he(q) = uicontrol(d, 'Style', 'edit', 'String', num2str(getf(fields{q, 1}, d0)), 'Position', [DW-140 yy 120 24], ...
                'FontSize', 10, 'BackgroundColor', C.input, 'ForegroundColor', C.txt);
        end
        yy = DH - 20 - 34 * (nfld + 1);
        uicontrol(d, 'Style', 'text', 'String', 'Repair controls', 'Position', [20 yy DW-290 20], 'FontSize', 10, 'FontName', FN, ...
            'ForegroundColor', C.txt, 'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');
        ctl = {'pv', 'p'}; cur = 'pv'; if isfield(S.adv, 'repair_controls'), cur = S.adv.repair_controls; end
        hp = uicontrol(d, 'Style', 'popupmenu', 'String', {'Active power and voltage set points', 'Active power only'}, ...
            'Value', find(strcmp(cur, ctl)), 'Position', [DW-260 yy 240 24], 'FontSize', 10, 'BackgroundColor', C.input, 'ForegroundColor', C.txt);
        hm = uicontrol(d, 'Style', 'text', 'String', '', 'Position', [20 44 DW-40 18], 'FontSize', 9, 'ForegroundColor', C.amber, ...
            'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');
        uicontrol(d, 'Style', 'pushbutton', 'String', 'OK', 'Position', [DW-230 12 100 26], 'Callback', @okCb, 'BackgroundColor', C.btnMain, 'ForegroundColor', C.btnTxt);
        uicontrol(d, 'Style', 'pushbutton', 'String', 'Cancel', 'Position', [DW-120 12 100 26], 'Callback', @(~, ~) delete(d), 'BackgroundColor', C.btnGray, 'ForegroundColor', C.btnTxt);
        function v = getf(name, dflt)
            key = strrep(name, '.', '_');
            if isfield(S.adv, key), v = S.adv.(key); return; end
            parts = regexp(name, '\.', 'split'); v = dflt;
            for pp = 1:numel(parts), v = v.(parts{pp}); end
        end
        function okCb(~, ~)
            a = struct();
            for qq = 1:nfld
                v = str2double(get(he(qq), 'String'));
                if isnan(v) || ~isfinite(v) || v < 0
                    set(hm, 'String', ['"' fields{qq, 2} '" needs a number that is not negative.']); return;
                end
                a.(strrep(fields{qq, 1}, '.', '_')) = v;
            end
            a.repair_controls = ctl{get(hp, 'Value')};
            S.adv = a; delete(d);
            say('Advanced settings updated.'); stat('Settings updated', C.green);
        end
    end
    function o = applyAdvanced(o)
        f = fieldnames(S.adv);
        for q = 1:numel(f)
            v = S.adv.(f{q});
            switch f{q}
                case 'newton_tol', o.newton.tol = v;
                case 'newton_max_it', o.newton.max_it = v;
                case 'q_margin', o.q_margin = v;
                case 'cert_exact_max_bus', o.cert.exact_max_bus = v;
                case 'repair_max_rounds', o.repair.max_rounds = v;
                case 'repair_ramp_pct', o.repair.ramp_pct = v;
                case 'repair_dv_max', o.repair.dv_max = v;
                case 'repair_time_ratio', o.repair.time_ratio = v;
                case 'repair_controls', o.repair.controls = v;
            end
        end
    end
    function onBatchLoad(~, ~)
        try
            ans1 = inputdlg({'Load scaling factors (for example 0.6:0.1:1.2):'}, 'Batch: Load Levels', 1, {'0.6:0.1:1.2'});
            if isempty(ans1), return; end
            v = str2num(ans1{1}); %#ok<ST2NM>
            if isempty(v) || any(~isfinite(v(:))) || any(v(:) <= 0)
                error('GRIT:input', 'The load scaling factors must be positive numbers. The field holds "%s".', ans1{1});
            end
            runLoadBatch(v);
        catch err
            fail(err);
        end
    end
    function runLoadBatch(v)
        o = readOptions(); c = readCase();
        stat(['Running the load batch of ' c ' ...'], C.amber);
        S.B = GRIT_Batch(c, 'load', v, o);
        msg = sprintf('Load batch of %s: %d levels in %.2f s.', c, size(S.B.table, 1), S.B.time);
        for q = 1:size(S.B.table, 1)
            msg = sprintf('%s\n   load x %.3f : %s', msg, S.B.table(q, 1), S.B.verdict{q});
        end
        say(msg); set(h.view, 'Value', 6); redraw(); stat('Batch done', C.green);
    end
    function onGuide(~, ~)
        msg = {'1. Type a MATPOWER case name in the CASE field, or use File > Open Case File.', ...
            '2. DISPATCH: let GRIT run the DC-OPF, or use the active power values stored in the case.', ...
            '3. LIMITS: leave the voltage fields blank to use VMIN and VMAX of the case.', ...
            '4. Press Check and Repair (Ctrl+R).', ...
            '5. Read the verdict card. FEASIBLE: the DC dispatch satisfies all AC limits.', ...
            '   VIOLATED: limits are violated, the table lists them. REPAIRED: a nearby dispatch satisfies all limits.', ...
            '   RELAXED: remaining violations are inside the relaxation you set. NO SOLUTION: no AC solution was found.', ...
            '6. Analysis menu: batch runs (N-1 of all branches, load levels) and the plots.', ...
            '7. File > Write Report saves a Markdown report of the last run.', '', ...
            'The manual (Doc/GRIT_Manual_v1.0.0.pdf) describes the method, every option and the limitations.'};
        d = dialog('Name', 'GRIT User Guide', 'Color', C.bg, 'Position', [scr(3)/2-360 scr(4)/2-190 720 380]);
        uicontrol(d, 'Style', 'text', 'String', msg, 'Position', [24 56 672 300], 'FontSize', 10, 'FontName', FN, ...
            'ForegroundColor', C.txt, 'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');
        pdf = fullfile(root, 'Doc', ['GRIT_Manual_v' GRIT_Version() '.pdf']);
        if exist(pdf, 'file')
            uicontrol(d, 'Style', 'pushbutton', 'String', 'Open the manual (PDF)', 'Position', [24 14 200 28], 'Callback', @(~, ~) open(pdf), ...
                'BackgroundColor', C.btnMain, 'ForegroundColor', C.btnTxt);
        end
        uicontrol(d, 'Style', 'pushbutton', 'String', 'Close', 'Position', [596 14 100 28], 'Callback', @(~, ~) delete(d), ...
            'BackgroundColor', C.btnGray, 'ForegroundColor', C.btnTxt);
    end
    function onCite(~, ~)
        msg = {'If you use GRIT in your work, please cite:', '', ...
            ['F. Y. Hou, "GRIT: Grid Realizability Inspection Tool, Version ' GRIT_Version() '," 2026.'], ...
            '[Online]. Available: https://github.com/GriRes/GRIT', '', ...
            'GRIT uses MATPOWER. Please also cite:', '', ...
            'R. D. Zimmerman, C. E. Murillo-Sanchez, and R. J. Thomas, "MATPOWER: Steady-State Operations,', ...
            'Planning and Analysis Tools for Power Systems Research and Education," IEEE Trans. Power Syst.,', ...
            'vol. 26, no. 1, pp. 12-19, Feb. 2011.'};
        d = dialog('Name', 'Citation Info', 'Color', C.bg, 'Position', [scr(3)/2-340 scr(4)/2-140 680 280]);
        uicontrol(d, 'Style', 'edit', 'Max', 20, 'Enable', 'inactive', 'String', msg, 'Position', [20 54 640 206], 'FontSize', 10, 'FontName', FN, ...
            'ForegroundColor', C.txt, 'BackgroundColor', C.panel, 'HorizontalAlignment', 'left');
        uicontrol(d, 'Style', 'pushbutton', 'String', 'Close', 'Position', [560 14 100 28], 'Callback', @(~, ~) delete(d), ...
            'BackgroundColor', C.btnGray, 'ForegroundColor', C.btnTxt);
    end
    function r = getResult()
        r = S.R;
    end
    function r = getBatch()
        r = S.B;
    end
    function hdr(str)
        y = y - 20;
        uicontrol(fig, 'Style', 'text', 'String', str, 'Position', [x0 y bw 15], 'FontSize', 8, 'FontWeight', 'bold', ...
            'FontName', FN, 'ForegroundColor', C.accent, 'BackgroundColor', C.side, 'HorizontalAlignment', 'left');
    end
    function e = edt(str)
        y = y - 26;
        e = uicontrol(fig, 'Style', 'edit', 'String', str, 'Position', [x0 y bw 23], 'FontSize', 10, 'FontName', FN, ...
            'BackgroundColor', C.input, 'ForegroundColor', C.txt, 'HorizontalAlignment', 'left');
    end
    function e = lab(str, val)
        y = y - 24;
        uicontrol(fig, 'Style', 'text', 'String', str, 'Position', [x0 y-2 bw-76 18], 'FontSize', 9, 'FontName', FN, ...
            'ForegroundColor', C.txt, 'BackgroundColor', C.side, 'HorizontalAlignment', 'left');
        e = uicontrol(fig, 'Style', 'edit', 'String', val, 'Position', [x0+bw-72 y 72 21], 'FontSize', 9, 'FontName', FN, ...
            'BackgroundColor', C.input, 'ForegroundColor', C.txt);
    end
    function p = pop(items)
        y = y - 26;
        p = uicontrol(fig, 'Style', 'popupmenu', 'String', items, 'Position', [x0 y bw 23], 'FontSize', 9, 'FontName', FN, ...
            'BackgroundColor', C.input, 'ForegroundColor', C.txt);
    end
    function c = chk(str, val)
        y = y - 22;
        c = uicontrol(fig, 'Style', 'checkbox', 'String', str, 'Value', val, 'Position', [x0 y bw 20], 'FontSize', 9, 'FontName', FN, ...
            'ForegroundColor', C.txt, 'BackgroundColor', C.side);
    end
    function b = btn(str, cb, col)
        y = y - 30;
        b = uicontrol(fig, 'Style', 'pushbutton', 'String', str, 'Position', [x0 y bw 26], 'FontSize', 9, 'FontName', FN, ...
            'BackgroundColor', col, 'ForegroundColor', C.btnTxt, 'Callback', cb);
    end
    function say(msg)
        S.log{end+1} = msg;
        lines = regexp(msg, '\n', 'split');
        old = get(h.con, 'String'); if ischar(old), old = cellstr(old); end
        lines = regexprep(lines, '[\x00-\x1F]', '');
        txt = [old(:); lines(:)];
        set(h.con, 'String', txt, 'Value', numel(txt), 'ListboxTop', max(1, numel(txt) - 5));
    end
    function stat(msg, col)
        set(h.status, 'String', msg, 'ForegroundColor', col); drawnow;
    end
    function v = num(hh, name, allowEmpty, lo)
        str = strtrim(get(hh, 'String'));
        if isempty(str)
            if allowEmpty, v = []; return; end
            error('GRIT:input', 'The field "%s" is empty.', name);
        end
        v = str2double(str);
        if isnan(v) || ~isfinite(v) || v < lo
            error('GRIT:input', 'The field "%s" needs a number that is at least %g. It holds "%s".', name, lo, str);
        end
    end
    function o = readOptions()
        o = GRIT_Config();
        o.verbose = 0;
        src = {'dcopf', 'case'}; o.dispatch.source = src{get(h.source, 'Value')};
        o.dispatch.load_scale = num(h.scale, 'Load scaling', false, 1e-6);
        sl = {'headroom', 'pmax', 'single'}; o.slack.mode = sl{get(h.slack, 'Value')};
        o.limits.v_min = num(h.vmin, 'Voltage minimum', true, 1e-6);
        o.limits.v_max = num(h.vmax, 'Voltage maximum', true, 1e-6);
        if ~isempty(o.limits.v_min) && ~isempty(o.limits.v_max) && o.limits.v_min > o.limits.v_max
            error('GRIT:input', 'The voltage minimum is above the voltage maximum.');
        end
        fl = {'S', 'P', 'I'}; o.limits.flow = fl{get(h.flow, 'Value')};
        o.limits.rate_scale = num(h.rscale, 'Rating scaling', false, 1e-6);
        o.newton.enforce_q = get(h.qlim, 'Value') > 0;
        if get(h.cert, 'Value') > 0, o.cert.mode = 'auto'; else, o.cert.mode = 'off'; end
        o.repair.enable = get(h.repair, 'Value') > 0;
        o.relax.v = num(h.relv, 'Accepted voltage relaxation', false, 0);
        o.relax.flow_pct = num(h.relf, 'Accepted loading relaxation', false, 0);
        o.compare.opf = get(h.opf, 'Value') > 0;
        o = applyAdvanced(o);
    end
    function c = readCase()
        c = strtrim(get(h.case, 'String'));
        if isempty(c), error('GRIT:input', 'No case is selected.'); end
    end
    function onBrowse(~, ~)
        [f, p] = uigetfile({'*.m;*.mat', 'MATPOWER case (*.m, *.mat)'}, 'Select a MATPOWER case');
        if isequal(f, 0), return; end
        set(h.case, 'String', fullfile(p, f));
    end
    function onRun(~, ~)
        try
            o = readOptions(); c = readCase();
            stat(['Running ' c ' ...'], C.amber);
            S.R = GRIT_Run(c, o);
            say(evalc('GRIT_Print(S.R)'));
            fill();
            if get(h.view, 'Value') == 6, set(h.view, 'Value', 1); end
            redraw();
            stat(sprintf('Done: %s, %s in %.3f s', S.R.name, S.R.verdict, S.R.time.total), C.green);
        catch err
            fail(err);
        end
    end
    function onBatch(~, ~)
        try
            o = readOptions(); c = readCase();
            stat(['Running the N-1 batch of ' c ' ...'], C.amber);
            S.B = GRIT_Batch(c, 'n-1', [], o);
            cnt = S.B.count; nm = S.B.verdict_names; msg = sprintf('N-1 batch of %s: %d outages in %.2f s.', c, size(S.B.table, 1), S.B.time);
            for k = 1:6, if cnt(k) > 0, msg = sprintf('%s %s %d.', msg, nm{k}, cnt(k)); end, end
            say(msg);
            set(h.view, 'Value', 6); redraw();
            stat('Batch done', C.green);
        catch err
            fail(err);
        end
    end
    function fail(err)
        first = regexp(err.message, '\n', 'split'); first = first{1};
        if strncmp(err.identifier, 'GRIT:', 5)
            say(['Input or data problem: ' first]);
        else
            say(['Error: ' first]);
            if ~isempty(err.stack), say(sprintf('   in %s, line %d', err.stack(1).name, err.stack(1).line)); end
        end
        stat(['Stopped: ' first], C.red);
    end
    function fill()
        R = S.R;
        vc = C.txt;
        switch R.verdict
            case 'FEASIBLE', vc = C.green;
            case {'REPAIRED', 'RELAXED'}, vc = C.blue;
            case 'VIOLATED', vc = C.amber;
            case 'NO_SOLUTION', vc = C.red;
        end
        vname = strrep(R.verdict, '_', ' ');
        set(h.card(1), 'String', vname, 'ForegroundColor', vc);
        if isempty(R.check)
            set(h.card(2:5), 'String', '-');
            set(h.table, 'Data', cell(0, 6));
        else
            K = R.check;
            set(h.card(2), 'String', sprintf('%d', K.n_viol));
            set(h.card(3), 'String', sprintf('%.3f - %.3f', K.v_min, K.v_max));
            set(h.card(4), 'String', sprintf('%.1f %%', K.max_loading_pct));
            set(h.card(5), 'String', sprintf('%.1f MW', K.loss));
            T = R.violations;
            for r = 1:size(T, 1)
                for cc = 3:5, T{r, cc} = sprintf('%.4f', T{r, cc}); end
            end
            set(h.table, 'Data', T);
        end
        set(h.card(6), 'String', sprintf('%.3f s', R.time.total));
    end
    function setView(k)
        set(h.view, 'Value', k); redraw();
    end
    function redraw()
        ax = h.ax; cla(ax, 'reset');
        set(ax, 'Color', C.panel, 'XColor', C.dim, 'YColor', C.dim, 'Box', 'on', 'FontSize', 9);
        hold(ax, 'on');
        k = get(h.view, 'Value');
        R = S.R;
        if k == 6
            if isempty(S.B), note('Run the batch first.'); return; end
            T = S.B.table; cols = [C.green; C.amber; C.blue; C.blue; C.red; C.dim];
            for c6 = 1:6
                i = find(T(:, 2) == c6);
                if ~isempty(i), plot(ax, i, max(T(i, 3), 0), 'o', 'Color', cols(c6, :), 'MarkerFaceColor', cols(c6, :), 'MarkerSize', 4); end
            end
            xlabel(ax, 'Outage (order of the list)'); ylabel(ax, 'Number of violations');
            title(ax, 'N-1 batch: violations per outage', 'Color', C.txt);
            return;
        end
        if isempty(R) || isempty(R.check), note('No AC solution to show.'); return; end
        K = R.check; A = R.ac;
        switch k
            case 1
                n = size(A.bus, 1);
                plot(ax, 1:n, A.bus(:, 5), '-', 'Color', C.red); plot(ax, 1:n, A.bus(:, 4), '-', 'Color', C.red);
                plot(ax, 1:n, A.bus(:, 2), '.', 'Color', C.accent, 'MarkerSize', 9);
                xlabel(ax, 'Bus (internal order)'); ylabel(ax, 'Voltage magnitude (pu)');
                title(ax, 'Voltage magnitude and limits', 'Color', C.txt); xlim(ax, [0 n + 1]);
            case 2
                p = A.branch(:, 10); i = find(~isnan(p));
                if isempty(i), note('The case has no branch ratings.'); return; end
                bar(ax, i, p(i), 'FaceColor', C.accent, 'EdgeColor', 'none');
                plot(ax, [0 numel(p) + 1], [100 100], '-', 'Color', C.red);
                xlabel(ax, 'Branch (internal order)'); ylabel(ax, 'Loading (percent of rating)');
                title(ax, 'Branch loading at the AC solution', 'Color', C.txt); xlim(ax, [0 numel(p) + 1]);
            case 3
                plot(ax, A.branch(:, 11), A.branch(:, 4), '.', 'Color', C.accent, 'MarkerSize', 9);
                m = max(abs([A.branch(:, 11); A.branch(:, 4); 1]));
                plot(ax, [-m m], [-m m], '-', 'Color', C.dim);
                xlabel(ax, 'DC active flow (MW)'); ylabel(ax, 'AC active flow (MW)');
                title(ax, sprintf('AC and DC active flow, largest difference %.2f MW', A.max_flow_error), 'Color', C.txt);
            case 4
                g = size(A.gen, 1);
                bar(ax, 1:g, [R.dc.pg(A.gen(:, 1)), A.gen(:, 4)], 'EdgeColor', 'none');
                xlabel(ax, 'Generator (internal order)'); ylabel(ax, 'Active power (MW)');
                title(ax, 'Dispatch: DC (first bar) and AC with losses and repair (second bar)', 'Color', C.txt);
            case 5
                if isempty(R.price), note('The loss factors were not computed.'); return; end
                plot(ax, 1:numel(R.price.itl), R.price.itl, '.', 'Color', C.accent, 'MarkerSize', 9);
                xlabel(ax, 'Bus (internal order)'); ylabel(ax, 'Loss change per MW injected');
                title(ax, 'Marginal loss factors at the fixed dispatch', 'Color', C.txt);
        end
        hold(ax, 'off');
        function note(str)
            text(0.5, 0.5, str, 'Parent', ax, 'Units', 'normalized', 'HorizontalAlignment', 'center', 'Color', C.dim, 'FontSize', 11);
            set(ax, 'XTick', [], 'YTick', []);
        end
    end
    function f = writeReport(f)
        if isempty(S.R), error('GRIT:input', 'There is no result yet. Press Run first.'); end
        f = GRIT_Report(S.R, f);
    end
    function onReport(~, ~)
        try
            if isempty(S.R), error('GRIT:input', 'There is no result yet. Press Run first.'); end
            nm = regexprep(S.R.name, '[^A-Za-z0-9_]', '_');
            [f, p] = uiputfile({'*.md', 'Markdown report (*.md)'}, 'Write report', ['GRIT_report_' nm '.md']);
            if isequal(f, 0), return; end
            out = GRIT_Report(S.R, fullfile(p, f));
            say(['Report written: ' out]); stat('Report written', C.green);
        catch err
            fail(err);
        end
    end
    function onSave(~, ~)
        try
            if isempty(S.R), error('GRIT:input', 'There is no result yet. Press Run first.'); end
            [f, p] = uiputfile({'*.mat', 'MAT-file (*.mat)'}, 'Save result', 'GRIT_result.mat');
            if isequal(f, 0), return; end
            R = S.R; %#ok<NASGU>
            save(fullfile(p, f), 'R');
            say(['Result saved: ' fullfile(p, f)]); stat('Result saved', C.green);
        catch err
            fail(err);
        end
    end
    function onAbout(~, ~)
        msg = {['GRIT' TM ' - Grid Realizability Inspection Tool'], ['Version ' GRIT_Version() ' (2026)'], ...
            'AC Feasibility Check and Repair of DC Dispatch', ['A tool of the GriRes' TM ' Suite (Grid Resilience Suite)'], '', ...
            'Copyright (c) 2026 Francis Yunhe Hou', 'License: GPL-3.0-or-later. A commercial license is available.', '', ...
            'Author:   Dr. Francis Yunhe Hou', 'Contact:  fyhou@vt.edu, yunhe.hou@gmail.com', ...
            'Profile:  https://ece.vt.edu/people/profile/francis-hou.html', 'Homepage: https://francisyhou.github.io', ...
            'Website:  https://github.com/GriRes/GRIT', '', ...
            'Portions of this software were developed with the assistance of Claude, an AI system', ...
            'made by Anthropic. All AI-generated code has been reviewed, tested, and validated by the author.'};
        d = dialog('Name', 'About GRIT', 'Color', C.bg, 'Position', [scr(3)/2-330 scr(4)/2-200 660 400]);
        tx = 24;
        logo96 = fullfile(root, 'Config', 'grires_logo_96.png');
        if exist(logo96, 'file')
            try
                im2 = imread(logo96); i2h = size(im2, 1); i2w = size(im2, 2);
                ax2 = axes('Parent', d, 'Units', 'pixels', 'Position', [24 400-24-i2h i2w i2h], 'Visible', 'off');
                image('CData', im2, 'Parent', ax2);
                set(ax2, 'XTick', [], 'YTick', [], 'XLim', [0.5 i2w + 0.5], 'YLim', [0.5 i2h + 0.5], 'YDir', 'reverse', 'Visible', 'off');
                tx = 24 + i2w + 16;
            catch
            end
        end
        uicontrol(d, 'Style', 'text', 'String', msg, 'Position', [tx 54 660-tx-20 326], 'FontSize', 10, 'FontName', FN, ...
            'ForegroundColor', C.txt, 'BackgroundColor', C.bg, 'HorizontalAlignment', 'left');
        uicontrol(d, 'Style', 'pushbutton', 'String', 'Close', 'Position', [540 14 100 28], 'Callback', @(~, ~) delete(d), ...
            'BackgroundColor', C.btnGray, 'ForegroundColor', C.btnTxt);
    end
end
