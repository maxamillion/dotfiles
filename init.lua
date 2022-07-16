require('plugins')

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.autoindent = true
vim.opt.cursorline = true
vim.opt.eol = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
vim.g.termguicolors = true

vim.wo.colorcolumn = "80"

vim.g.mapleader = " "

-- treesitter
require('nvim-treesitter.configs').setup {
    ensure_installed = { 'lua', 'python', 'go' },
    auto_install = true,
    highlight = {
        enable = true,
    },
}

-- luasnip
local luasnip = require('luasnip')
luasnip.config.set_config {
    history = true,
    updateevents = 'TextChanged,TextChangedI',
    enable_autosnippets = true,
}

-- LSP
require('nvim-lsp-setup').setup({
    default_mappings = true,
    on_attach = function(client, bufnr)
        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
          local bufopts = { noremap=true, silent=true, buffer=bufnr }
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
    end,
    servers = {
        gopls = {},
        pylsp = {},
        sumneko_lua = {
            single_file_support = true,
            settings = {
                Lua = {
                    diagnostics = {
                        globals = { 'vim', 'use' }
                    }
                }
            },
        },
    }
})

local lspkind = require('lspkind')
lspkind.init()

-- Completion
local cmp = require('cmp')
cmp.setup {
    mapping = {
        ['<C-n>'] = cmp.mapping.select_next_item { behavior = cmp.SelectBehavior.Insert },
        ['<C-p>'] = cmp.mapping.select_prev_item { behavior = cmp.SelectBehavior.Insert },
        ['<C-d>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<C-y>'] = cmp.mapping.confirm { select = true },
    },
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body)
        end,
    },
    formatting = {
        format = lspkind.cmp_format {
            with_text = true,
            menu = {
                buffer = "[buf]",
                nvim_lsp = "[LSP]",
                luasnip = "[snip]",
            }
        }
    },
    sources = {
        { name = 'nvim_lsp' },
        { name = 'nvim_lua' },
        { name = 'path' },
        { name = 'luasnip' },
        { name = 'buffer' },
    },
    experimental = {
        native_menu = false,
        ghost_text = true,
    },
}


local opts = { noremap=true, silent=true }

-- telescope
require('telescope')
vim.keymap.set('n', '<leader>ff', require('telescope.builtin').find_files, opts)
vim.keymap.set('n', '<leader>fg', require('telescope.builtin').live_grep, opts)
vim.keymap.set('n', '<leader>fb', require('telescope.builtin').buffers, opts)
vim.keymap.set('n', '<leader>fh', require('telescope.builtin').help_tags, opts)
vim.keymap.set('n', '<leader>dj', vim.diagnostic.goto_next, opts)
vim.keymap.set('n', '<leader>dk', vim.diagnostic.goto_prev, opts)

require('nvim_comment').setup {
    comment_empty = false,
}
require('nvim-surround').setup()
require('hardline').setup {
    theme = "gruvbox"
}

-- indent-blanklines
require("indent_blankline").setup {
        -- for example, context is off by default, use this to turn it on
    show_current_context = true,
    show_current_context_start = true,
}

-- colorcolumn
require("virt-column").setup()

local group = vim.api.nvim_create_augroup('fmt', { clear = true })
vim.api.nvim_create_autocmd('BufWritePre', { command = 'undojoin | Neoformat', group = group })

-- vim command(s)
vim.cmd[[
colorscheme gruvbox
]]
