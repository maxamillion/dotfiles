vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function()
    use 'wbthomason/packer.nvim'

    use {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "neovim/nvim-lspconfig",
    }

    use {
        'junnplus/nvim-lsp-setup',
        requires = {
            'neovim/nvim-lspconfig',
            'williamboman/nvim-lsp-installer',
        }
    }
    use 'onsails/lspkind.nvim'

    use "lukas-reineke/virt-column.nvim"

    use 'hrsh7th/nvim-cmp'
    use 'hrsh7th/cmp-nvim-lsp'
    use 'hrsh7th/cmp-buffer'
    use 'hrsh7th/cmp-path'
    use 'hrsh7th/cmp-nvim-lua'
    use 'hrsh7th/cmp-nvim-lsp-document-symbol'
    use 'saadparwaiz1/cmp_luasnip'
    use 'L3MON4D3/LuaSnip'

    use "lukas-reineke/indent-blankline.nvim"

    use 'nvim-treesitter/nvim-treesitter'
    use 'nvim-lua/lsp-status.nvim'

    use {
        'nvim-telescope/telescope.nvim',
        requires = { {'nvim-lua/plenary.nvim'} }
    }


    use 'ojroques/nvim-hardline'
    use {'fenetikm/falcon'}
    use { "ellisonleao/gruvbox.nvim" }

    use {'terrortylor/nvim-comment'}
    use {'kylechui/nvim-surround'}

    use {'yuntan/neovim-indent-guides'}
    use {'Glench/Vim-Jinja2-Syntax' }
    use {
        'kyazdani42/nvim-tree.lua',
          requires = {
            'kyazdani42/nvim-web-devicons', -- optional, for file icons
        },
    }
end)

