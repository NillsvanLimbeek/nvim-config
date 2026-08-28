-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- This file contains installation and configuration of plugins outside of MINI.
-- They significantly improve user experience in a way not yet possible with MINI.
-- These are mostly plugins that provide programming language specific behavior.
--
-- Use this file to install and configure other such plugins.

-- Make concise helpers for installing/adding plugins in two stages
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later
local now_if_args = Config.now_if_args

-- Color scheme ================================================================

-- 'catppuccin/nvim' provides the Catppuccin color scheme. Set up now (not later)
-- so it applies before first screen draw, replacing 'miniwinter' from
-- 'plugin/30_mini.lua'.
now(function()
  add('catppuccin/nvim')
  require('catppuccin').setup({
    flavour = 'mocha',
    transparent_background = true,
    -- Catppuccin only auto-detects plugins installed via 'vim.pack', 'pckr',
    -- or 'lazy.nvim' - never 'mini.deps' (used here) - so 'mini.nvim'
    -- integration (MiniStatusline mode colors, MiniIndentscope, MiniClue, etc.)
    -- has to be turned on explicitly instead of relying on auto-detection.
    integrations = { mini = true },
    -- Give the selected item in popup menus (completion, etc.) more contrast
    -- than the default 'surface0', matching blink.cmp's selection highlight.
    custom_highlights = function(colors)
      return {
        PmenuSel = { bg = colors.surface1, style = { 'bold' } },
        PmenuKindSel = { bg = colors.surface1, fg = colors.blue, style = { 'bold' } },
        PmenuExtraSel = { bg = colors.surface1, fg = colors.overlay0, style = { 'bold' } },
        -- With 'transparent_background = true', Pmenu's background would
        -- otherwise be see-through - force it solid so the completion popup
        -- (which now has a border) doesn't look like a hole in the editor.
        Pmenu = { bg = colors.mantle },
        PmenuKind = { bg = colors.mantle },
      }
    end,
  })
  vim.cmd.colorscheme('catppuccin')
end)

-- Cursor =======================================================================

-- 'sphamba/smear-cursor.nvim' animates a trailing smear effect as the cursor
-- moves, making it easier to track - ported from the previous config's
-- LazyVim extra ('lazyvim.plugins.extras.ui.smear-cursor'), same opts.
-- Skipped inside Neovide, which already animates the cursor natively.
--
-- 'mini.animate's own cursor animation (see 'plugin/30_mini.lua') would
-- otherwise conflict, but is left disabled there by default already.
if vim.g.neovide == nil then
  later(function()
    add('sphamba/smear-cursor.nvim')
    require('smear_cursor').setup({
      hide_target_hack = true,
      cursor_color = 'none',
    })
  end)
end

-- Tree-sitter ================================================================

-- Tree-sitter is a tool for fast incremental parsing. It converts text into
-- a hierarchical structure (called tree) that can be used to implement advanced
-- and/or more precise actions: syntax highlighting, textobjects, indent, etc.
--
-- Tree-sitter support is built into Neovim (see `:h treesitter`). However, it
-- requires two extra pieces that don't come with Neovim directly:
-- - Language parsers: programs that convert text into trees. Some are built-in
--   (like for Lua), 'nvim-treesitter' provides many others.
--   NOTE: It requires third party software to build and install parsers.
--   See the link for more info in "Requirements" section of the MiniMax README.
-- - Query files: definitions of how to extract information from trees in
--   a useful manner (see `:h treesitter-query`). 'nvim-treesitter' also provides
--   these, while 'nvim-treesitter-textobjects' provides the ones for Neovim
--   textobjects (see `:h text-objects`, `:h MiniAi.gen_spec.treesitter()`).
--
-- Add these plugins now if file (and not 'mini.starter') is shown after startup.
--
-- Troubleshooting:
-- - Run `:checkhealth vim.treesitter nvim-treesitter` to see potential issues.
-- - In case of errors related to queries for Neovim bundled parsers (like `lua`,
--   `vimdoc`, `markdown`, etc.), manually install them via 'nvim-treesitter'
--   with `:TSInstall <language>`. Be sure to have necessary system dependencies
--   (see MiniMax README section for software requirements).
now_if_args(function()
  add({
    source = 'nvim-treesitter/nvim-treesitter',
    -- Update tree-sitter parser after plugin is updated
    hooks = { post_checkout = function() vim.cmd('TSUpdate') end },
    -- Pin to the commit just before the plugin dropped Neovim=0.11 support
    checkout = '90cd6580e720caedacb91fdd587b747a6e77d61f',
  })
  add({
    source = 'nvim-treesitter/nvim-treesitter-textobjects',
    -- Pin to the commit corresponding to 'nvim-treesitter' commit
    checkout = '93d60a475f0b08a8eceb99255863977d3a25f310',
  })

  -- Define languages which will have parsers installed and auto enabled
  -- After changing this, restart Neovim once to install necessary parsers. Wait
  -- for the installation to finish before opening a file for added language(s).
  local languages = {
    -- These are already pre-installed with Neovim. Used as an example.
    'lua',
    'vimdoc',
    'markdown',
    -- Add here more languages with which you want to use tree-sitter
    -- To see available languages:
    -- - Execute `:=require('nvim-treesitter').get_available()`
    -- - Visit 'SUPPORTED_LANGUAGES.md' file at
    --   https://github.com/nvim-treesitter/nvim-treesitter
    --
    -- TypeScript/JavaScript/React (matches 'vtsls', see 'Language servers'
    -- below), Vue, and HTML (also needed by 'nvim-ts-autotag' below, which
    -- requires tree-sitter to be active for the buffer's filetype).
    'javascript', 'typescript', 'tsx', 'vue', 'css', 'html',
    -- Inline markdown constructs (bold/italic/links/inline code) - without
    -- this, only block-level markdown highlights correctly.
    'markdown_inline',
    -- Common everyday filetypes: shell scripts, JSON/JSONC (already formatted
    -- via 'prettier', see "Formatting" below, but otherwise unparsed).
    'bash', 'json',
    -- Editing tree-sitter query files themselves, and embedded regex (e.g.
    -- inside Lua patterns/JS RegExp literals, comments).
    'query', 'regex',
  }
  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then require('nvim-treesitter').install(to_install) end

  -- Enable tree-sitter after opening a file for a target language
  local filetypes = {}
  for _, lang in ipairs(languages) do
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      table.insert(filetypes, ft)
    end
  end
  local ts_start = function(ev) vim.treesitter.start(ev.buf) end
  Config.new_autocmd('FileType', filetypes, ts_start, 'Start tree-sitter')
end)

-- HTML/JSX/Vue tag auto-closing ================================================

-- Neither built-in Neovim nor 'mini.pairs' (which only pairs brackets/quotes)
-- auto-closes or auto-renames matching HTML-style tags (`<div>` -> `</div>`,
-- and keeping both ends in sync when editing a tag name). 'windwp/nvim-ts-autotag'
-- adds that, using tree-sitter to find the matching tag - so it requires
-- tree-sitter to already be active for the buffer (see 'languages' above:
-- 'html', 'vue', 'tsx' cover this config's relevant filetypes; 'javascript'
-- and 'typescript' are aliased to the same tag config internally).
later(function()
  add('windwp/nvim-ts-autotag')
  require('nvim-ts-autotag').setup()
end)

-- Jumping ======================================================================

-- 'folke/flash.nvim' jumps to any visible location (labeled 2-character search)
-- or tree-sitter node, replacing 'mini.jump2d' (disabled in 'plugin/30_mini.lua').
--
-- NOTE: uses bare `s` / `S`, which are core Vim's "substitute" motions - not
-- otherwise mapped in this config, so nothing is lost. `r` / `R` are only
-- overridden in operator-pending/visual mode (see below), so their Normal-mode
-- meaning ("replace char" / "Replace mode") is untouched. This also means
-- 'mini.surround' (see 'plugin/30_mini.lua') had to move off its default bare
-- `s`-prefixed mappings onto a `gs` prefix instead, to avoid colliding with
-- Flash's `s` / `S`.
--
-- Example usage:
-- - `s` then 2 characters - jump to any matching visible location
-- - `S` then a character - jump to a tree-sitter node starting with it
-- - `dr` + 2 characters - delete text up to a remote (not-yet-jumped-to) match
-- - `<C-s>` while searching (`/`, `?`) - toggle Flash's labels on search matches
--
-- See also:
-- - `:h flash.nvim` (after install) or https://github.com/folke/flash.nvim
later(function()
  add('folke/flash.nvim')
  require('flash').setup()

  vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = 'Flash jump' })
  vim.keymap.set(
    { 'n', 'x', 'o' },
    'S',
    function() require('flash').treesitter() end,
    { desc = 'Flash treesitter jump' }
  )
  vim.keymap.set('o', 'r', function() require('flash').remote() end, { desc = 'Flash remote' })
  vim.keymap.set(
    { 'o', 'x' },
    'R',
    function() require('flash').treesitter_search() end,
    { desc = 'Flash treesitter search' }
  )
  vim.keymap.set('c', '<C-s>', function() require('flash').toggle() end, { desc = 'Toggle Flash search' })
end)

-- Completion ==================================================================

-- 'saghen/blink.cmp' replaces 'mini.completion' (disabled in 'plugin/30_mini.lua')
-- as the completion engine: LSP + path + buffer sources and its own popup menu.
-- `<Tab>` / `<S-Tab>` navigate the menu (or jump forward/backward through
-- snippet placeholders when it isn't open) and `<CR>` accepts - see the
-- `keymap` table below for why that needs overriding the 'default' preset.
-- Registers its own `<Tab>` / `<S-Tab>` / `<CR>` insert-mode mappings, which -
-- since this section runs before 'mini.keymap's in 'plugin/30_mini.lua' -
-- take priority over the 'pmenu_*' multistep ones there whenever blink's menu
-- is visible. Signature help is left to 'noice.nvim' (see its "Command line
-- UI" section below) rather than blink's own - see the `signature` field.
--
-- Snippet *expansion* is still handled by 'mini.snippets' (set up in
-- 'plugin/30_mini.lua', which already depends on 'rafamadriz/friendly-snippets')
-- via the 'mini_snippets' preset below, rather than blink's own snippet engine.
--
-- Placed before "Language servers" below so `vim.lsp.config('*', ...)` registers
-- blink's LSP capabilities before any server gets enabled/attached.
--
-- NOTE: fuzzy matching uses a native Rust module, built from source on install/
-- update via the 'post_checkout' hook below - requires a working 'cargo'.
now_if_args(function()
  add({
    source = 'saghen/blink.cmp',
    checkout = 'v1.10.2',
    hooks = {
      post_checkout = function(args) vim.system({ 'cargo', 'build', '--release' }, { cwd = args.path }):wait() end,
    },
  })

  require('blink.cmp').setup({
    -- The 'super-tab' preset makes `<Tab>` *accept* the selected item
    -- (VSCode-style). Override it here to instead just navigate the menu -
    -- matching 'mini.completion's old `<Tab>` / `<S-Tab>` behavior - and
    -- accept on `<CR>` instead. `'fallback'` runs whatever `<CR>` would've
    -- done otherwise (i.e. 'mini.keymap's 'minipairs_cr' step) when the menu
    -- isn't visible.
    keymap = {
      preset = 'default',
      ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
      ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
      ['<CR>'] = { 'accept', 'fallback' },
    },
    sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
    snippets = { preset = 'mini_snippets' },
    -- Disabled: blink's cmdline completion (on by default) draws its own
    -- floating popup for the `:`/`/` command line, fighting 'mini.cmdline'
    -- (see 'plugin/30_mini.lua'), which already drives that via the native
    -- wildmenu - and neither renders reliably under 'noice.nvim's floating
    -- cmdline below, which left `<Tab>` not cycling any results.
    cmdline = { enabled = false },
    completion = {
      menu = { border = 'rounded' },
      documentation = { auto_show = true, window = { border = 'rounded' } },
      -- Disabled: accepting a function completion (e.g. 'console.log') would
      -- auto-insert '()' as a snippet with an empty tabstop inside, silently
      -- starting a 'mini.snippets' session every time - its `•`/`∎` empty-
      -- tabstop markers (see 'plugin/30_mini.lua') then linger at the cursor
      -- until that session is explicitly ended (`<C-c>` or jumping past it).
      -- 'mini.pairs' already closes brackets when typed manually, so this
      -- isn't needed.
      accept = { auto_brackets = { enabled = false } },
    },
    -- Left disabled (blink's own default): 'noice.nvim' (see 'plugin/40_plugins.lua'
    -- below, "Command line UI" section) already shows LSP signature help on its
    -- own by default, with nicer Treesitter-based markdown rendering. Enabling
    -- it here too just overlaps blink's plainer signature window on top of it.
    signature = { enabled = false },
  })

  -- Advertise to servers that Neovim now supports certain set of completion and
  -- signature features through 'blink.cmp'.
  vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })
end)

-- Language servers ===========================================================

-- Language Server Protocol (LSP) is a set of conventions that power creation of
-- language specific tools. It requires two parts:
-- - Server - program that performs language specific computations.
-- - Client - program that asks server for computations and shows results.
--
-- Here Neovim itself is a client (see `:h vim.lsp`). Language servers need to
-- be installed separately based on your OS, CLI tools, and preferences.
-- See note about 'mason.nvim' at the bottom of the file.
--
-- Neovim's team collects commonly used configurations for most language servers
-- inside 'neovim/nvim-lspconfig' plugin.
--
-- Add it now if file (and not 'mini.starter') is shown after startup.
--
-- Troubleshooting:
-- - Run `:checkhealth vim.lsp` to see potential issues.
now_if_args(function()
  add('neovim/nvim-lspconfig')

  -- 'folke/lazydev.nvim' teaches 'lua_ls' about things it can't infer on its
  -- own from `$VIMRUNTIME` alone: globals injected by plugins at runtime
  -- (like `Snacks`) and `vim.uv` (libuv) typings - without the slow, noisy
  -- full-'runtimepath' library scan the 'lua_ls' snippet below explicitly
  -- avoids. Only activates for files under this config / installed plugin
  -- directories, not Lua files in general.
  --
  -- NOTE: doesn't cover 'mini.nvim's own `MiniXxx` globals (e.g. `MiniDeps`,
  -- `MiniFiles`) - unlike 'snacks.nvim', they're assigned to `_G` from inside
  -- a function body (`_G.MiniDeps = MiniDeps` in 'mini/deps.lua'), not via
  -- a top-level `---@type`-annotated declaration lazydev's scanner can pick
  -- up. Listed explicitly in `diagnostics.globals` below instead.
  add('folke/lazydev.nvim')
  require('lazydev').setup({
    library = {
      { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
    },
  })

  -- 'lua_ls' config below is 'nvim-lspconfig's own suggested snippet (see its
  -- doc comment in 'lsp/lua_ls.lua') for using it primarily to edit a Neovim
  -- config: makes it aware of the Neovim runtime (`vim` global, `:h lua-guide`
  -- APIs, etc.) instead of flagging them as undefined, without pulling in all
  -- of 'runtimepath' (slow, and noisy on this config's own files - see the
  -- linked issue in that same doc comment).
  vim.lsp.config('lua_ls', {
    on_init = function(client)
      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if
          path ~= vim.fn.stdpath('config')
          and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc'))
        then
          return
        end
      end

      client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
        runtime = { version = 'LuaJIT', path = { 'lua/?.lua', 'lua/?/init.lua' } },
        workspace = {
          checkThirdParty = false,
          library = {
            vim.env.VIMRUNTIME,
            vim.api.nvim_get_runtime_file('lua/lspconfig', false)[1],
          },
        },
        -- 'mini.nvim' module globals used (as bare 'MiniXxx.func()') across
        -- this config's 'plugin/*.lua' files - see NOTE above 'lazydev.setup()'.
        diagnostics = {
          globals = {
            'MiniAi', 'MiniAlign', 'MiniBasics', 'MiniBufremove', 'MiniClue',
            'MiniDeps', 'MiniDiff', 'MiniExtra', 'MiniFiles', 'MiniGit',
            'MiniIcons', 'MiniIndentscope', 'MiniInput', 'MiniKeymap', 'MiniMap',
            'MiniMisc', 'MiniNotify', 'MiniSnippets', 'MiniSplitjoin',
            'MiniStatusline', 'MiniTrailspace',
          },
        },
      })
    end,
  })

  -- 'vtsls' (TypeScript/JavaScript) config, ported from LazyVim's
  -- 'lang.typescript' extra. 'nvim-lspconfig's own 'lsp/vtsls.lua' already
  -- provides a sensible 'cmd'/'filetypes'/'root_dir' - only 'settings' needs
  -- adding here (inlay hints, workspace TS version, etc.). Applied to both
  -- 'typescript' and 'javascript', matching the source config.
  local vtsls_ts_settings = {
    updateImportsOnFileMove = { enabled = 'always' },
    suggest = { completeFunctionCalls = true },
    inlayHints = {
      enumMemberValues = { enabled = true },
      functionLikeReturnTypes = { enabled = true },
      parameterNames = { enabled = 'literals' },
      parameterTypes = { enabled = true },
      propertyDeclarationTypes = { enabled = true },
      variableTypes = { enabled = false },
    },
  }
  -- 'vue_ls' (see below) handles the template/CSS side of '.vue' Single-File
  -- Components, but needs 'vtsls' to run the actual TypeScript side, via this
  -- plugin bundled with the 'vue-language-server' Mason package - see the
  -- "Vue support" section of 'nvim-lspconfig's own doc comment in
  -- 'lsp/vtsls.lua'. Ported from LazyVim's 'lang.vue' extra.
  local vue_ts_plugin_path = vim.fn.stdpath('data') .. '/mason/packages/vue-language-server/node_modules/@vue/language-server'
  vim.lsp.config('vtsls', {
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue' },
    settings = {
      complete_function_calls = true,
      vtsls = {
        enableMoveToFileCodeAction = true,
        autoUseWorkspaceTsdk = true,
        experimental = {
          maxInlayHintLength = 30,
          completion = { enableServerSideFuzzyMatch = true },
        },
        tsserver = {
          globalPlugins = {
            {
              name = '@vue/typescript-plugin',
              location = vue_ts_plugin_path,
              languages = { 'vue' },
              configNamespace = 'typescript',
              enableForWorkspaceTypeScriptVersions = true,
            },
          },
        },
      },
      typescript = vtsls_ts_settings,
      javascript = vtsls_ts_settings,
    },
  })

  -- 'eslint' (linting), ported from LazyVim's 'linting.eslint' extra.
  -- 'workingDirectories = { mode = "auto" }' helps it find the right config
  -- in a monorepo. Fix-on-save uses 'nvim-lspconfig's own documented recipe
  -- (see its doc comment in 'lsp/eslint.lua'): the base 'on_attach' exposes
  -- the ':LspEslintFixAll' command, run here via 'BufWritePre'.
  local eslint_base_on_attach = vim.lsp.config.eslint.on_attach
  vim.lsp.config('eslint', {
    settings = { workingDirectories = { mode = 'auto' } },
    on_attach = function(client, bufnr)
      if eslint_base_on_attach then eslint_base_on_attach(client, bufnr) end
      vim.api.nvim_create_autocmd('BufWritePre', { buffer = bufnr, command = 'LspEslintFixAll' })
    end,
  })

  -- 'tailwindcss', ported from LazyVim's 'lang.tailwind' extra. Excludes
  -- 'markdown' from 'nvim-lspconfig's (fairly broad) default filetype list -
  -- attaching there is more noise than help.
  vim.lsp.config('tailwindcss', {
    filetypes = vim.tbl_filter(function(ft) return ft ~= 'markdown' end, vim.lsp.config.tailwindcss.filetypes),
  })

  -- Use `:h vim.lsp.enable()` to automatically enable language server based on
  -- the rules provided by 'nvim-lspconfig'.
  -- Use `:h vim.lsp.config()` or 'after/lsp/' directory to configure servers.
  vim.lsp.enable({ 'lua_ls', 'vtsls', 'vue_ls', 'eslint', 'tailwindcss' })
end)

-- Diagnostics =================================================================

-- 'rachartier/tiny-inline-diagnostic.nvim' renders diagnostics as a compact,
-- single-line message right after the offending code (with fancier styling
-- and multiline support) instead of Neovim's plain built-in virtual text -
-- ported from the previous config. Replaces (rather than adds to) the
-- `virtual_text` entry in `diagnostic_opts` set up in 'plugin/10_options.lua'.
later(function()
  add('rachartier/tiny-inline-diagnostic.nvim')
  require('tiny-inline-diagnostic').setup({
    options = {
      multilines = { enabled = true, always_show = true },
    },
  })
  vim.diagnostic.config({ virtual_text = false })
end)

-- Buffer deletion =============================================================

-- Ported from LazyVim config. 'folke/snacks.nvim' provides several independent
-- modules (enabled individually via the `setup()` table below):
-- - `bufdelete` - delete buffer(s) without closing their window/split. Used by
--   the '<Leader>bd' / '<Leader>bo' / '<Leader>bc' mappings below.
-- - `dashboard` - start screen shown when Neovim is opened with no file args.
--   Replaces 'mini.starter' (disabled in 'plugin/30_mini.lua').
--   NOTE: the LazyVim source config also had a `startup` section (shows
--   "plugins loaded in Xms"), dropped here - it calls `require('lazy.stats')`,
--   hard-wired to 'lazy.nvim' (MiniMax uses 'mini.deps' instead), which would
--   error on every dashboard open.
-- - `lazygit` - open 'lazygit' in a floating terminal. Requires 'lazygit' to be
--   installed separately. Used by the '<Leader>gg' mapping below.
-- - `scroll` - smooth (animated) scrolling.
-- - `statuscolumn` - custom statuscolumn combining line numbers, signs (e.g. from
--   'mini.diff'), and folds. Replaces the plain 'number'/'signcolumn' rendering
--   from 'plugin/10_options.lua'.
-- - `picker`/`explorer` - fuzzy finder and file-tree sidebar. Replaces
--   'mini.pick' (disabled in 'plugin/30_mini.lua'; 'mini.files' stays, bound to
--   '-' and '<Leader>ef' in 'plugin/20_keymaps.lua'). Also takes over
--   `vim.ui.select()`, via its `ui_select` default.
--
-- NOTE: `notifier` module was skipped - it overlaps with 'mini.notify', already
-- active in 'plugin/30_mini.lua'.
--
-- Set up now (not later), since 'dashboard' needs to render before first draw.
now(function()
  add('folke/snacks.nvim')
  require('snacks').setup({
    bufdelete = {},
    dashboard = {
      preset = {
        header = [[

⠀⠀⠀⠀⣠⣤⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣤⣄⠀⠀⠀⠀
⠀⠀⠀⠸⣿⣿⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣇⠀⠀⠀
⢀⣤⣤⣼⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣶⣾⣿⣿⣿⣿⣿⣿⣷⣶⣤⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣤⣤⡀
⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⢀⣴⡞⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣦⡀⠀⠀⠀⠀⢀⣴⣶⣿⣿⣿⣿⣿⣿⣿
⠙⠿⣿⡿⠏⢿⣿⣿⣿⣿⣦⣀⠀⣴⣿⠟⣤⡿⢁⣿⢛⣿⣿⣿⣿⣿⣿⣿⣿⡈⢿⣤⡙⣿⣦⡀⢀⣰⣿⣿⣿⣿⡿⠙⢿⣿⠿⠋
⠀⠀⠀⠀⠀⠀⠙⠻⣿⣿⣿⠃⠺⠛⠟⠻⠛⠓⠛⠛⠛⠛⠛⠛⠛⠛⠛⠟⠛⠟⠆⠟⠛⠚⠟⠳⠘⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⡏⠀⡀⠂⠌⠀⠌⠠⠁⠌⠠⠁⠌⠠⠁⠌⠐⡀⠡⠀⠂⠈⠐⠀⢂⠐⠀⢸⠟⠉⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢀⣀⣀⣀⣀⣀⣀⣀⣀⣁⣐⣈⣀⣀⣐⣀⣀⣂⣐⣀⣈⣀⣂⣀⣐⣀⣂⣁⣀⣁⣂⣀⣁⣀⣀⣀⣀⣀⣀⣀⠀⠀⠀⠀
⠀⠀⠀⠀⠻⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠇⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⡿⠋⠉⠛⠻⣿⣿⣿⣿⣿⣿⠟⠉⠉⠛⠿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⢻⣿⣿⣿⠁⠀⠀⠀⠀⠀⠹⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⡇⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⠀⠀⠀⠀⠀⠀⢠⣿⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢻⣿⣦⣀⣀⣀⣠⣴⣿⡿⠿⣿⣷⣄⣀⣀⣀⣤⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠻⢿⣿⣿⣿⣿⣇⠀⠀⣨⣿⣿⣿⣿⠿⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⢰⣶⣬⣍⢙⣛⠛⠙⠋⠙⣉⡉⣭⣴⣾⡄⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⡇⣍⡛⠿⠏⣷⣿⣿⣿⢸⣿⣿⣧⢿⠿⠟⣁⢻⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣴⣿⣿⣿⡇⠾⣿⣷⣆⣤⣭⣭⣍⢨⣭⣭⣥⠐⣶⣿⡟⢸⣿⣿⣿⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢠⣴⣾⣿⣦⣼⣿⣿⣿⣿⠟⠃⣷⣬⣙⡛⠻⠿⣿⣿⢸⣿⡿⠿⢘⣋⣥⣶⠘⠻⣿⣿⣿⣿⣷⣴⣾⣿⣶⡄⠀⠀⠀⠀
⠀⠀⠀⠀⢺⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⠀⢻⣿⣿⣿⣷⣶⣶⣶⣶⣶⣶⣾⣿⣿⣿⡏⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠙⠛⢻⣿⣿⣿⣿⡆⠀⠀⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠀⠀⠀⠀⢠⣿⣿⣿⣿⡟⠛⠋⠁⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠈⠿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠁⠀⠀⠀⠀⠀⠈⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠙⠛⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠛⠛⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠚⠋⠀⠀⠀⠀⠀⠀⠀⠀
      ]],
      },
      sections = {
        { section = 'header' },
      },
    },
    lazygit = {},
    scroll = {},
    statuscolumn = {},
    explorer = {},
    picker = {
      sources = {
        explorer = {
          layout = { layout = { position = 'right' } },
          win = {
            list = {
              keys = {
                ['h'] = 'toggle_hidden',
                ['i'] = 'toggle_ignored',
                ['z'] = 'explorer_close_all',
              },
            },
          },
        },
      },
    },
  })
end)

-- 'mini.completion' (see 'plugin/30_mini.lua') doesn't know about the picker's
-- input buffer and would otherwise show its own keyword-completion dropdown
-- (sourced from words in other open buffers) while typing a query. It already
-- special-cases 'TelescopePrompt' this same way by default - add the same for
-- 'snacks.nvim'.
Config.new_autocmd(
  'FileType',
  'snacks_picker_input',
  function() vim.b.minicompletion_disable = true end,
  'Disable mini.completion in the picker input'
)

-- LSP goto actions (from 'folke/snacks.nvim' README defaults). Uses the picker
-- for a list when there are multiple results.
--
-- NOTE: 'gr' skipped - already used by 'mini.operators' for the replace
-- operator (see 'plugin/30_mini.lua'). LSP references stay on '<Leader>lR'.
-- NOTE: 'gy' overrides 'mini.basics'' default "copy to system clipboard"
-- mapping (see 'plugin/30_mini.lua') - must be set after it, hence being here
-- instead of alongside the other general mappings in 'plugin/20_keymaps.lua'.
vim.keymap.set('n', 'gd', function() Snacks.picker.lsp_definitions() end, { desc = 'Goto definition' })
vim.keymap.set('n', 'gD', function() Snacks.picker.lsp_declarations() end, { desc = 'Goto declaration' })
vim.keymap.set('n', 'gI', function() Snacks.picker.lsp_implementations() end, { desc = 'Goto implementation' })
vim.keymap.set('n', 'gy', function() Snacks.picker.lsp_type_definitions() end, { desc = 'Goto type definition' })
vim.keymap.set('n', 'gai', function() Snacks.picker.lsp_incoming_calls() end, { desc = 'Calls incoming' })
vim.keymap.set('n', 'gao', function() Snacks.picker.lsp_outgoing_calls() end, { desc = 'Calls outgoing' })

-- 'vtsls'-specific mappings and commands (ported from LazyVim's
-- 'lang.typescript' extra, see 'Language servers' above), scoped to buffers
-- where it actually attaches - matches how 'nvim-lspconfig's declarative
-- per-server 'keys' option works.
--
-- NOTE: 'gD' ("Goto Source Definition", jump past a '.d.ts' to the real
-- source) skipped - would have collided with the bare 'gD' mapping above
-- (Snacks' declaration picker).
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or client.name ~= 'vtsls' then return end
    local buf = ev.buf

    -- 'gR' shows results via a quickfix list + 'snacks.nvim' picker (this
    -- config has no 'folke/trouble.nvim', which the source LazyVim mapping
    -- uses instead).
    vim.keymap.set('n', 'gR', function()
      client:exec_cmd(
        { command = 'typescript.findAllFileReferences', arguments = { vim.uri_from_bufnr(buf) } },
        { bufnr = buf },
        function(_, result)
          if not result then return end
          vim.fn.setqflist({}, ' ', {
            title = 'File References',
            items = vim.lsp.util.locations_to_items(result, client.offset_encoding),
          })
          Snacks.picker.qflist()
        end
      )
    end, { buffer = buf, desc = 'File references' })

    vim.keymap.set('n', '<Leader>cM', function()
      vim.lsp.buf.code_action({ apply = true, context = { only = { 'source.addMissingImports.ts' }, diagnostics = {} } })
    end, { buffer = buf, desc = 'Add missing imports' })

    vim.keymap.set('n', '<Leader>cD', function()
      vim.lsp.buf.code_action({ apply = true, context = { only = { 'source.fixAll.ts' }, diagnostics = {} } })
    end, { buffer = buf, desc = 'Fix all diagnostics' })

    vim.keymap.set('n', '<Leader>cV', function()
      client:exec_cmd({ command = 'typescript.selectTypeScriptVersion' }, { bufnr = buf })
    end, { buffer = buf, desc = 'Select TS workspace version' })
  end,
})

-- 'vtsls's "move to file" refactor needs the client to resolve the actual
-- destination file interactively - 'Snacks.util.lsp.on()' hooks this the same
-- way LazyVim's declarative per-server 'setup' option does.
Snacks.util.lsp.on({ name = 'vtsls' }, function(_, client)
  client.commands['_typescript.moveToFileRefactoring'] = function(command)
    ---@type string, string, lsp.Range
    local action, uri, range = unpack(command.arguments)

    local function move(newf)
      client:request('workspace/executeCommand', { command = command.command, arguments = { action, uri, range, newf } })
    end

    local fname = vim.uri_to_fname(uri)
    client:request('workspace/executeCommand', {
      command = 'typescript.tsserverRequest',
      arguments = {
        'getMoveToRefactoringFileSuggestions',
        {
          file = fname,
          startLine = range.start.line + 1,
          startOffset = range.start.character + 1,
          endLine = range['end'].line + 1,
          endOffset = range['end'].character + 1,
        },
      },
    }, function(_, result)
      ---@type string[]
      local files = result.body.files
      table.insert(files, 1, 'Enter new path...')
      vim.ui.select(files, {
        prompt = 'Select move destination:',
        format_item = function(f) return vim.fn.fnamemodify(f, ':~:.') end,
      }, function(f)
        if f and f:find('^Enter new path') then
          vim.ui.input({
            prompt = 'Enter move destination:',
            default = vim.fn.fnamemodify(fname, ':h') .. '/',
            completion = 'file',
          }, function(newf) return newf and move(newf) end)
        elseif f then
          move(f)
        end
      end)
    end)
  end
end)

-- Command line UI =============================================================

-- 'folke/noice.nvim' can move the command line (and its completion popup menu)
-- into a floating window centered in the UI - `ext_cmdline`, a Neovim UI
-- extension that nothing in MINI or 'snacks.nvim' implements.
--
-- Message/notification handling and LSP progress are left disabled - same
-- call made for 'snacks.nvim's own `notifier` module above - 'mini.notify'
-- (see 'plugin/30_mini.lua') keeps handling those. LSP hover/signature-help
-- (e.g. 'K') are kept on Noice's defaults on purpose: nicer (Treesitter-based)
-- markdown rendering than Neovim's plain 'vim.lsp.buf.hover()' float, and
-- nothing else in this config touches them.
later(function()
  add({ source = 'folke/noice.nvim', depends = { 'MunifTanjim/nui.nvim' } })

  -- With the cmdline moved into a floating window, the classic bottom row(s)
  -- reserved for it (`:h 'cmdheight'`) are no longer needed and would just
  -- show as an empty gap below the statusline.
  vim.o.cmdheight = 0

  require('noice').setup({
    cmdline = { view = 'cmdline_popup' },
    popupmenu = { enabled = true, backend = 'nui' },
    messages = { enabled = false },
    notify = { enabled = false },
    lsp = { progress = { enabled = false } },
    presets = {
      command_palette = true, -- position the cmdline and popupmenu together
      bottom_search = true, -- classic bottom cmdline for search
    },
    -- The 'hover' view (LSP hover, e.g. 'K') has no border by default.
    -- NOTE: `position.row` bumped from the default `1` to `2` - with a border
    -- added, the default renders the popup's top row on the *same* screen row
    -- as the cursor, covering the inspected keyword instead of appearing below it.
    --
    -- 'popupmenu' is the insert-mode completion menu - now only used as a
    -- fallback for native Vim completion (e.g. manual `<C-n>`/`<C-x><C-f>`),
    -- since 'blink.cmp' (see "Completion" section above) draws its own menu
    -- instead of going through this. Still has no border by default; row
    -- offset to avoid covering the cursor is handled automatically once a
    -- border is set (unlike 'hover' above).
    views = {
      hover = {
        border = { style = 'rounded' },
        position = { row = 2, col = 0 },
      },
      popupmenu = {
        border = { style = 'rounded' },
      },
    },
  })
end)

-- Formatting =================================================================

-- Programs dedicated to text formatting (a.k.a. formatters) are very useful.
-- Neovim has built-in tools for text formatting (see `:h gq` and `:h 'formatprg'`).
-- They can be used to configure external programs, but it might become tedious.
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup.
later(function()
  add('stevearc/conform.nvim')

  -- 'prettier' filetypes, ported from LazyVim's 'formatting.prettier' extra.
  -- Dropped its 'has_parser' check (calls out to `prettier --file-info` to
  -- infer a parser for filetypes outside this list) - this config only ever
  -- assigns 'prettier' to filetypes already known to be supported, so that
  -- fallback path would never actually run.
  local prettier_fts = {
    'css', 'graphql', 'handlebars', 'html', 'javascript', 'javascriptreact',
    'json', 'jsonc', 'less', 'markdown', 'scss', 'typescript',
    'typescriptreact', 'vue', 'yaml',
  }
  local formatters_by_ft = {}
  for _, ft in ipairs(prettier_fts) do formatters_by_ft[ft] = { 'prettier' } end

  -- Only run 'prettier' in projects that actually have a config for it
  -- (`.prettierrc`, `prettier.config.js`, a `"prettier"` key in
  -- 'package.json', etc. - anything `prettier --find-config-path` resolves).
  -- Otherwise it would format-on-save every project unconditionally, fighting
  -- projects that intentionally use only 'eslint' for formatting (its
  -- fix-on-save is set up separately, see 'Language servers' above).
  -- Memoized per file - `:h conform-formatters-prettier-condition`-style
  -- check, ported from LazyVim's 'M.has_config' ('LazyVim.memoize' there).
  local has_prettier_config_cache = {}
  local has_prettier_config = function(_, ctx)
    if has_prettier_config_cache[ctx.filename] == nil then
      vim.fn.system({ 'prettier', '--find-config-path', ctx.filename })
      has_prettier_config_cache[ctx.filename] = vim.v.shell_error == 0
    end
    return has_prettier_config_cache[ctx.filename]
  end

  -- See also:
  -- - `:h Conform`
  -- - `:h conform-options`
  -- - `:h conform-formatters`
  require('conform').setup({
    default_format_opts = {
      -- Allow formatting from LSP server if no dedicated formatter is available
      lsp_format = 'fallback',
    },
    format_on_save = { timeout_ms = 500, lsp_format = 'fallback' },
    -- Map of filetype to formatters
    -- Make sure that necessary CLI tool is available
    formatters_by_ft = formatters_by_ft,
    formatters = {
      prettier = { condition = has_prettier_config },
    },
  })
end)

-- Snippets ===================================================================

-- Although 'mini.snippets' provides functionality to manage snippet files, it
-- deliberately doesn't come with those.
--
-- The 'rafamadriz/friendly-snippets' is currently the largest collection of
-- snippet files. They are organized in 'snippets/' directory (mostly) per language.
-- 'mini.snippets' is designed to work with it as seamlessly as possible.
-- See `:h MiniSnippets.gen_loader.from_lang()`.
later(function() add('rafamadriz/friendly-snippets') end)

-- Package manager for language servers ========================================

-- 'mason-org/mason.nvim' (a.k.a. "Mason") is a great tool (package manager) for
-- installing external language servers, formatters, and linters. It provides
-- a unified interface for installing, updating, and deleting such programs.
--
-- The caveat is that these programs will be set up to be mostly used inside Neovim.
-- If you need them to work elsewhere, consider using other package managers.
--
-- None of the servers referenced above (see 'Language servers' section) are
-- installed system-wide, so install them with `:Mason` / `:MasonInstall`.
now_if_args(function()
  add('mason-org/mason.nvim')
  require('mason').setup()
end)

-- Honorable mentions =========================================================

-- Beautiful, usable, well maintained color schemes outside of 'mini.nvim' and
-- have full support of its highlight groups. Use if you don't like 'miniwinter'
-- enabled in 'plugin/30_mini.lua' or other suggested 'mini.hues' based ones.
-- MiniDeps.now(function()
--   -- Install only those that you need
--   add('sainnhe/everforest')
--   add('Shatur/neovim-ayu')
--   add('ellisonleao/gruvbox.nvim')
--
--   -- Enable only one
--   vim.cmd('color everforest')
-- end)
