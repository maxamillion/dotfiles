""""""""""""""""""""""""""" BEGIN VIM PLUG
" Specify a directory for plugins
" - For Neovim: stdpath('data') . '/plugged'
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')
Plug 'Glench/Vim-Jinja2-Syntax'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'davidhalter/jedi-vim'
Plug 'bling/vim-airline'
Plug 'scrooloose/syntastic'
Plug 'sjl/badwolf'
" Initialize plugin system
call plug#end()
""""""""""""""""""""""""""" END VIM PLUG

""""""""""""""""""""""""""" BEING GENERAL SETTINGS

set relativenumber
set number
set cursorline

" fuck the arrow keys
noremap <left> <nop>
noremap <up> <nop>
noremap <down> <nop>
noremap <right> <nop>

" Yank from current cursor position to end of line
map Y y$
" Yank content in OS's clipboard. `o` stands for "OS's Clipoard".
vnoremap <leader>yo "*y
" Paste content from OS's clipboard
nnoremap <leader>po "*p

" clear highlight after search
noremap <silent><Leader>/ :nohls<CR>

" Change leader
let mapleader = "\<space>"

" better ESC
inoremap <C-k> <Esc>

" Seriously, guys. It's not like :W is bound to anything anyway.
command! W :w

set modelines=0
set noeol
if exists('+relativenumber')
  set relativenumber
endif
set numberwidth=3
set winwidth=83
set ruler
set showcmd

set matchtime=2

set completeopt=longest,menuone,preview
set autoindent
""""""""""""""""""""""""""" END GENERAL SETTINGS


""" Indent-guides Settings
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_exclude_filetypes = ['help', 'nerdtree']
let g:indent_guides_start_level=2
let g:indent_guides_guide_size=1
let g:indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  ctermbg=238
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=236

""" Jedi settings
let g:jedi#goto_command = "<leader>d"
let g:jedi#goto_assignments_command = "<leader>g"
let g:jedi#goto_definitions_command = ""
let g:jedi#documentation_command = "K"
let g:jedi#usages_command = "<leader>n"
let g:jedi#completions_command = "<C-Space>"
let g:jedi#rename_command = "<leader>r"

colorscheme badwolf

""" Syntastic
let g:syntastic_check_on_wq = 0
let g:syntastic_enable_signs=1
let g:syntastic_auto_loc_list=1

" For sphinx, the default is something else and it drives me nuts
let g:syntastic_rst_checkers = ['sphinx']

" shortcuts because I'm lazy
cnoreabbrev SC w <bar> SyntasticCheck
cnoreabbrev SR SyntasticReset
cnoreabbrev AR AirlineRefresh
cnoreabbrev TT TagbarToggle
cnoreabbrev SP set paste

""" Airline settings
" Set airline to use not use powerline fancy font symbols
let g:airline_powerline_fonts = 0
if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif
let g:airline_left_sep = ''
let g:airline_right_sep = ''

" Random filetypes
"
" asciidoc - *.adoc
au BufRead,BufNewFile *.adoc set filetype=asciidoc
autocmd BufNewFile,BufRead *.j2,*.jinja,*.jinja2  set ft=jinja

autocmd FileType python setlocal expandtab sw=4 sts=4 ts=8
autocmd FileType yaml setlocal expandtab sw=2 sts=2 ts=4
autocmd FileType ruby setlocal expandtab sw=2 sts=2 ts=4
autocmd FileType go setlocal ts=4 sts=4 sw=4 noexpandtab

" Some webfonts don't handle this well which screws up ssh (hterm) on ChromeOS
set showbreak=>
set listchars=tab:+\ ,eol:¬,extends:>,precedes:<,trail:_
" Trailing whitespace override
" Only shown when not in insert mode so I don't go insane.
augroup trailing
    au!
    au InsertEnter * :set listchars-=trail:_
    au InsertLeave * :set listchars+=trail:_
augroup END

" Set this because reasons
set eol
