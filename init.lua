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
vim.opt.undofile = true

vim.g.termguicolors = true

vim.wo.colorcolumn = "80"

vim.g.mapleader = " " -- MAKE SURE THIS IS DONE BEFORE lazy.nvim loads

-- tab stuff
vim.keymap.set('', '<leader>tn', '<Cmd>tabnew<CR>', { noremap = true })
vim.keymap.set('', '<leader>tc', '<Cmd>tabclose<CR>', { noremap = true })
vim.keymap.set('', '<leader>tp', '<Cmd>tabprevious<CR>', { noremap = true })
vim.keymap.set('', '<leader>tm', '<Cmd>tabmove<CR>', { noremap = true })
vim.keymap.set('', '<leader>1', '1gt', { noremap = true })
vim.keymap.set('', '<leader>2', '2gt', { noremap = true })
vim.keymap.set('', '<leader>3', '3gt', { noremap = true })
vim.keymap.set('', '<leader>4', '4gt', { noremap = true })
vim.keymap.set('', '<leader>5', '5gt', { noremap = true })
vim.keymap.set('', '<leader>6', '6gt', { noremap = true })
vim.keymap.set('', '<leader>7', '7gt', { noremap = true })
vim.keymap.set('', '<leader>8', '8gt', { noremap = true })
vim.keymap.set('', '<leader>9', '9gt', { noremap = true })

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup(
    {
        'lukas-reineke/virt-column.nvim',
        'hrsh7th/nvim-cmp',
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-path',
        'hrsh7th/cmp-nvim-lua',
        'hrsh7th/cmp-nvim-lsp-document-symbol',
        'saadparwaiz1/cmp_luasnip',
        'L3MON4D3/LuaSnip',
        "lukas-reineke/indent-blankline.nvim",
        'nvim-treesitter/nvim-treesitter',
        'nvim-lua/lsp-status.nvim',
        'ojroques/nvim-hardline',
        'fenetikm/falcon',
        'ellisonleao/gruvbox.nvim',
        'terrortylor/nvim-comment',
        'kylechui/nvim-surround',
        'yuntan/neovim-indent-guides',
        'Glench/Vim-Jinja2-Syntax',
        'nvim-treesitter/nvim-treesitter',
        {
            'junnplus/lsp-setup.nvim',
            dependencies = {
                'neovim/nvim-lspconfig',
                'williamboman/mason.nvim',
                'williamboman/mason-lspconfig.nvim',
            }
        },
        {
            'nvim-telescope/telescope.nvim',
            dependencies = { {'nvim-lua/plenary.nvim'} }
        },
        {
            'kyazdani42/nvim-tree.lua',
              dependencies = {
                'kyazdani42/nvim-web-devicons', -- optional, for file icons
            },
        },
        {
        }
    }
)

-- treesitter
require('nvim-treesitter.configs').setup {
    ensure_installed = { 'lua', 'python', 'go', 'bash'},
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
require('lsp-setup').setup({
    default_mappings = true,
    on_attach = function(client, bufnr)
        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
    end,
    servers = {
        gopls = {},
        -- pylsp = {},
        ansiblels = {},
        lua_ls = {}
    }
})

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
    theme="gruvbox"
}

-- indent-blanklines
require("ibl").setup {}

-- nvim-tree
require("nvim-tree").setup()
vim.keymap.set('n', '<leader>ft', '<Cmd>NvimTreeOpen<CR>', { noremap = true })
vim.keymap.set('n', '<leader>fc', '<Cmd>NvimTreeClose<CR>', { noremap = true })

-- colorcolumn
require("virt-column").setup()

-- gruvboxr
require('gruvbox').setup({transparent_mode=true})

-- vim command(s)
vim.cmd('colorscheme gruvbox')
