-- Neovim ships no built-in ftplugin for 'vue', so 'commentstring' is left
-- empty. 'mini.comment' falls back to it whenever the cursor is on markup
-- that tree-sitter resolves to the 'vue' language itself (e.g. inside
-- <template>, since the vue parser handles tags directly instead of
-- injecting 'html'), which otherwise makes `gc` error there.
-- Inside <script>/<style> blocks, 'mini.comment' still prefers the
-- tree-sitter-injected language's own 'commentstring' over this default.
vim.bo.commentstring = '<!-- %s -->'
