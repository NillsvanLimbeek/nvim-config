-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

-- General mappings ===========================================================

-- Use this section to add custom general mappings. See `:h vim.keymap.set()`.

-- An example helper to create a Normal mode mapping
local nmap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set('n', lhs, rhs, { desc = desc })
end

-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap('[p', '<Cmd>exe "put! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "put "  . v:register<CR>', 'Paste Below')

-- Clear search highlight (mini.basics also provides `\h` to toggle it)
nmap('<Esc>', '<Cmd>nohlsearch<CR>', 'Clear search highlight')

-- Save with Cmd+S (macOS)
nmap('<D-s>', '<Cmd>w<CR>', 'Save file')

-- Buffer navigation
nmap('<Tab>', '<Cmd>bnext<CR>', 'Next buffer')
nmap('<S-Tab>', '<Cmd>bprevious<CR>', 'Prev buffer')

-- Keep visual selection active after indenting
vim.keymap.set('v', '<', '<gv', { desc = 'Indent left (keep selection)' })
vim.keymap.set('v', '>', '>gv', { desc = 'Indent right (keep selection)' })

-- Quick alternative to `<Leader>ef` below: open 'mini.files' at current file
-- and jump straight to its most recently focused entry.
nmap('-', function() MiniFiles.open(vim.api.nvim_buf_get_name(0), true) end, 'Open mini.files')

-- LSP goto actions (from 'folke/snacks.nvim' README defaults) are set up in
-- 'plugin/40_plugins.lua' - has to come after 'mini.basics' (see
-- 'plugin/30_mini.lua'), which sets a default 'gy' mapping this overrides.

-- Many general mappings are created by 'mini.basics'. See 'plugin/30_mini.lua'

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- Leader mappings ============================================================

-- Neovim has the concept of a Leader key (see `:h <Leader>`). It is a configurable
-- key that is primarily used for "workflow" mappings (opposed to text editing).
-- Like "open file explorer", "create scratch buffer", "pick from buffers".
--
-- In 'plugin/10_options.lua' <Leader> is set to <Space>, i.e. press <Space>
-- whenever there is a suggestion to press <Leader>.
--
-- This config uses a "two key Leader mappings" approach: first key describes
-- semantic group, second key executes an action. Both keys are usually chosen
-- to create some kind of mnemonic.
-- Example: `<Leader>f` groups "find" type of actions; `<Leader>ff` - find files.
-- Use this section to add Leader mappings in a structural manner.
--
-- Usually if there are global and local kinds of actions, lowercase second key
-- denotes global and uppercase - local.
-- Example: `<Leader>fs` / `<Leader>fS` - find workspace/document LSP symbols.
--
-- Many of the mappings use 'mini.nvim' modules set up in 'plugin/30_mini.lua'.

-- Create a global table with information about Leader groups in certain modes.
-- This is used to provide 'mini.clue' with extra clues.
-- Add an entry if you create a new group.
Config.leader_group_clues = {
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>c', desc = '+Code' },
  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>l', desc = '+Language' },
  { mode = 'n', keys = '<Leader>m', desc = '+Map' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>s', desc = '+Split/Search' },
  { mode = 'n', keys = '<Leader>t', desc = '+Tab' },
  { mode = 'n', keys = '<Leader>u', desc = '+UI' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },

  { mode = 'x', keys = '<Leader>c', desc = '+Code' },
  { mode = 'x', keys = '<Leader>g', desc = '+Git' },
  { mode = 'x', keys = '<Leader>l', desc = '+Language' },
}

-- Helpers for a more concise `<Leader>` mappings.
-- Most of the mappings use `<Cmd>...<CR>` string as a right hand side (RHS) in
-- an attempt to be more concise yet descriptive. See `:h <Cmd>`.
-- This approach also doesn't require the underlying commands/functions to exist
-- during mapping creation: a "lazy loading" approach to improve startup time.
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

-- b is for 'Buffer'. Common usage:
-- - `<Leader>bs` - create scratch (temporary) buffer
-- - `<Leader>ba` - navigate to the alternative buffer
-- - `<Leader>bw` - wipeout (fully delete) current buffer
local new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

nmap_leader('ba', '<Cmd>b#<CR>',                                 'Alternate')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
nmap_leader('bs', new_scratch_buffer,                            'Scratch')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>',        'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- From LazyVim config. Uses the 'folke/snacks.nvim' 'bufdelete' module, set up in
-- 'plugin/40_plugins.lua'. Replaces 'MiniBufremove.delete()' for plain delete
-- ('bD'/'bw'/'bW' - force delete / wipeout - stay on 'mini.bufremove').
nmap_leader('bd', function() Snacks.bufdelete() end,       'Delete buffer')
nmap_leader('bo', function() Snacks.bufdelete.other() end, 'Delete other buffers')
nmap_leader('bc', function() Snacks.bufdelete.all() end,   'Delete all buffers')

-- c is for 'Code'. Common usage:
-- - `<Leader>ca` - pick a code action to apply at the cursor (or over a visual
--   selection)
--
-- Renders as a floating window because 'snacks.nvim's `picker` module (set up
-- in 'plugin/40_plugins.lua') replaces `vim.ui.select()` with a Snacks picker
-- by default (`ui_select`) - same mechanism 'vim.lsp.buf.code_action()' already
-- uses internally to let you choose among multiple available actions.
--
-- The rest of the LazyVim-style 'c' group ('cM'/'cD'/'cV') is 'vtsls'-specific
-- (TypeScript/JavaScript only) - see 'plugin/40_plugins.lua'.
nmap_leader('ca', '<Cmd>lua vim.lsp.buf.code_action()<CR>', 'Code action')
xmap_leader('ca', '<Cmd>lua vim.lsp.buf.code_action()<CR>', 'Code action')

-- Top-level single-key mappings (from LazyVim/Snacks README defaults). Uses
-- 'folke/snacks.nvim' picker + explorer, set up in 'plugin/40_plugins.lua'.
-- Replaces the previous 'e' (Explore/Edit) group entirely, and most of the
-- 'f' (Find) group below - both used to be 'mini.pick'-based (now disabled,
-- see 'plugin/30_mini.lua'). 'mini.files' is still available via '-' above.
nmap_leader('<Space>', function() Snacks.picker.files() end,           'Smart find files')
nmap_leader(',',       function() Snacks.picker.buffers() end,         'Buffers')
nmap_leader('/',       function() Snacks.picker.grep() end,            'Grep')
nmap_leader(':',       function() Snacks.picker.command_history() end, 'Command history')
nmap_leader('e',       function() Snacks.explorer() end,               'Explorer')

-- f is for 'Fuzzy Find'. Common usage:
-- - `<Leader>ff` - find files; for best performance requires `ripgrep`
-- - `<Leader>fr` - recent files
--
-- The rest of the previous, larger 'mini.pick'-based group moved to the 's'
-- (Search) group and bare `g*`/`gr` LSP mappings above, matching Snacks'
-- own README default keymaps.
nmap_leader('fb', function() Snacks.picker.buffers() end,                                 'Buffers')
nmap_leader('fc', function() Snacks.picker.files({ cwd = vim.fn.stdpath('config') }) end, 'Find config file')
nmap_leader('ff', function() Snacks.picker.files() end,                                   'Find files')
nmap_leader('fg', function() Snacks.picker.git_files() end,                               'Find git files')
nmap_leader('fp', function() Snacks.picker.projects() end,                                'Projects')
nmap_leader('fr', function() Snacks.picker.recent() end,                                  'Recent files')

-- g is for 'Git'. Common usage:
-- - `<Leader>gs` - Git status picker
-- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- - `<Leader>gd` - Git diff (hunks) picker
-- - `<Leader>gg` - open 'lazygit'
--
-- Git pickers ('gb'/'gd'/'gf'/'gl'/'gL'/'gs'/'gS') use 'folke/snacks.nvim',
-- set up in 'plugin/40_plugins.lua', matching its README default keymaps.
-- This took over the 'gd'/'gD' (Diff/Diff buffer), 'gl'/'gL' (Log/Log buffer),
-- and 'gs' (Show at cursor) keys previously used for 'mini.git'/custom `:Git`
-- commands - moved to 'gw'/'gW' (Working diff), 'gh'/'gH' (Log, text), and
-- 'gI' (Info) below.
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
local git_log_buf_cmd = git_log_cmd .. ' --follow -- %'

nmap_leader('ga', '<Cmd>Git diff --cached<CR>',                 'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>',            'Added diff buffer')
nmap_leader('gb', function() Snacks.picker.git_branches() end,  'Branches')
nmap_leader('gc', '<Cmd>Git commit<CR>',                        'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',                'Commit amend')
nmap_leader('gd', function() Snacks.picker.git_diff() end,      'Diff (hunks)')
nmap_leader('gf', function() Snacks.picker.git_log_file() end,  'Log file')
nmap_leader('gg', function() Snacks.lazygit() end,              'Lazygit')
nmap_leader('gh', '<Cmd>' .. git_log_cmd .. '<CR>',             'Log (text)')
nmap_leader('gH', '<Cmd>' .. git_log_buf_cmd .. '<CR>',         'Log buffer (text)')
nmap_leader('gI', '<Cmd>lua MiniGit.show_at_cursor()<CR>',      'Info at cursor')
nmap_leader('gl', function() Snacks.picker.git_log() end,       'Log')
nmap_leader('gL', function() Snacks.picker.git_log_line() end,  'Log line')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>',     'Toggle overlay')
nmap_leader('gs', function() Snacks.picker.git_status() end,    'Status')
nmap_leader('gS', function() Snacks.picker.git_stash() end,     'Stash')
nmap_leader('gw', '<Cmd>Git diff<CR>',                          'Working diff')
nmap_leader('gW', '<Cmd>Git diff -- %<CR>',                     'Working diff buffer')

xmap_leader('gI', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Info at selection')

-- l is for 'Language'. Common usage:
-- - `<Leader>ld` - show more diagnostic details in a floating window
-- - `<Leader>lr` - perform rename via LSP
-- - `<Leader>ls` - navigate to source definition of symbol under cursor
--
-- NOTE: most LSP mappings represent a more structured way of replacing built-in
-- LSP mappings (like `:h gra` and others). This is needed because `gr` is mapped
-- by an "replace" operator in 'mini.operators' (which is more commonly used).
nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>',     'Actions')
nmap_leader('ld', '<Cmd>lua vim.diagnostic.open_float()<CR>',   'Diagnostic popup')
nmap_leader('lf', '<Cmd>lua require("conform").format()<CR>',   'Format')
nmap_leader('li', '<Cmd>lua vim.lsp.buf.implementation()<CR>',  'Implementation')
nmap_leader('lh', '<Cmd>lua vim.lsp.buf.hover()<CR>',           'Hover')
nmap_leader('ll', '<Cmd>lua vim.lsp.codelens.run()<CR>',        'Lens')
nmap_leader('lr', '<Cmd>lua vim.lsp.buf.rename()<CR>',          'Rename')
nmap_leader('lR', '<Cmd>lua vim.lsp.buf.references()<CR>',      'References')
nmap_leader('ls', '<Cmd>lua vim.lsp.buf.definition()<CR>',      'Source definition')
nmap_leader('lt', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', 'Type definition')

xmap_leader('lf', '<Cmd>lua require("conform").format()<CR>', 'Format selection')

-- m is for 'Map'. Common usage:
-- - `<Leader>mt` - toggle map from 'mini.map' (closed by default)
-- - `<Leader>mf` - focus on the map for fast navigation
-- - `<Leader>ms` - change map's side (if it covers something underneath)
nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>', 'Focus (toggle)')
nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>',      'Refresh')
nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>',  'Side (toggle)')
nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>',       'Toggle')

-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',    'Trim trailspace')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',          'Zoom toggle')

-- s is for 'Split' (window). Ported from LazyVim config.
--
-- Previously this group was 'Session' (via 'mini.sessions', commented out below
-- to free up 's' - re-add under a different key if/when needed).
-- - `<Leader>sn` - start new session
-- - `<Leader>sr` - read previously started session
-- - `<Leader>sd` - delete previously started session
-- local session_new = 'vim.ui.input({ prompt = "Session name: " }, MiniSessions.write)'
-- nmap_leader('sd', '<Cmd>lua MiniSessions.select("delete")<CR>', 'Delete')
-- nmap_leader('sn', '<Cmd>lua ' .. session_new .. '<CR>',         'New')
-- nmap_leader('sr', '<Cmd>lua MiniSessions.select("read")<CR>',   'Read')
-- nmap_leader('sw', '<Cmd>lua MiniSessions.write()<CR>',          'Write current')

nmap_leader('sv', '<C-w>v',         'Split window vertically')
nmap_leader('sx', '<Cmd>close<CR>', 'Close current split')

-- Search pickers (from LazyVim/Snacks README defaults). Uses 'folke/snacks.nvim'
-- picker, set up in 'plugin/40_plugins.lua'.
--
-- NOTE: 'sp' (Search for Plugin Spec, via `Snacks.picker.lazy()`) skipped - it
-- reads 'lazy.nvim' plugin specs, which don't exist here (MiniMax uses
-- 'mini.deps' instead).
nmap_leader('s"', function() Snacks.picker.registers() end,            'Registers')
nmap_leader('s/', function() Snacks.picker.search_history() end,       'Search history')
nmap_leader('sa', function() Snacks.picker.autocmds() end,             'Autocmds')
nmap_leader('sb', function() Snacks.picker.lines() end,                'Buffer lines')
nmap_leader('sB', function() Snacks.picker.grep_buffers() end,         'Grep open buffers')
nmap_leader('sc', function() Snacks.picker.command_history() end,      'Command history')
nmap_leader('sC', function() Snacks.picker.commands() end,             'Commands')
nmap_leader('sd', function() Snacks.picker.diagnostics() end,          'Diagnostics')
nmap_leader('sD', function() Snacks.picker.diagnostics_buffer() end,   'Buffer diagnostics')
nmap_leader('sg', function() Snacks.picker.grep() end,                 'Grep')
nmap_leader('sh', function() Snacks.picker.help() end,                 'Help pages')
nmap_leader('sH', function() Snacks.picker.highlights() end,           'Highlights')
nmap_leader('si', function() Snacks.picker.icons() end,                'Icons')
nmap_leader('sj', function() Snacks.picker.jumps() end,                'Jumps')
nmap_leader('sk', function() Snacks.picker.keymaps() end,              'Keymaps')
nmap_leader('sl', function() Snacks.picker.loclist() end,              'Location list')
nmap_leader('sm', function() Snacks.picker.marks() end,                'Marks')
nmap_leader('sM', function() Snacks.picker.man() end,                  'Man pages')
nmap_leader('sq', function() Snacks.picker.qflist() end,               'Quickfix list')
nmap_leader('sR', function() Snacks.picker.resume() end,               'Resume')
nmap_leader('ss', function() Snacks.picker.lsp_symbols() end,          'LSP symbols')
nmap_leader('sS', function() Snacks.picker.lsp_workspace_symbols() end,'LSP workspace symbols')
nmap_leader('su', function() Snacks.picker.undo() end,                 'Undo history')
nmap_leader('sw', function() Snacks.picker.grep_word() end,            'Word/selection')

xmap_leader('sw', function() Snacks.picker.grep_word() end, 'Word/selection')

-- t is for 'Tab'. Ported from LazyVim config.
--
-- Previously this group was 'Terminal' (built-in `:h :terminal`, commented out
-- below - not used).
-- nmap_leader('tT', '<Cmd>horizontal term<CR>', 'Terminal (horizontal)')
-- nmap_leader('tt', '<Cmd>vertical term<CR>',   'Terminal (vertical)')

nmap_leader('to', '<Cmd>tabnew<CR>',   'Open new tab')
nmap_leader('tx', '<Cmd>tabclose<CR>', 'Close current tab')
nmap_leader('tf', '<Cmd>tabnew %<CR>', 'Open current buffer in new tab')

-- u is for 'UI'. From LazyVim/Snacks README defaults.
nmap_leader('uC', function() Snacks.picker.colorschemes() end, 'Colorschemes')

-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
--
-- NOTE: previously included 'vc'/'vC' pickers over "core"-labeled files, via
-- `MiniExtra.pickers.visit_paths()`. Dropped along with 'mini.pick' (see
-- 'plugin/30_mini.lua'), which they needed as a rendering backend and has no
-- Snacks equivalent for 'mini.visits'' label tracking.
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>',    'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>',          'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>',       'Remove label')
-- stylua: ignore end
