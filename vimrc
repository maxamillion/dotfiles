call plug#begin('~/.vim/plugged')
Plug 'Glench/Vim-Jinja2-Syntax'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'davidhalter/jedi-vim'
" Plug 'ajh17/VimCompletesMe' " This stopped working for some reason
Plug 'sheerun/vim-polyglot'
Plug 'vim-airline/vim-airline'
Plug 'fatih/vim-go'
Plug 'rust-lang/rust.vim'
Plug 'sjl/badwolf'
Plug 'tpope/vim-endwise'
Plug 'gioele/vim-autoswap'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'Exafunction/codeium.vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
call plug#end()

set autoindent
set cursorline
set eol
set matchtime=2
set number
set numberwidth=3
set relativenumber
set ruler
set showcmd
set showmatch
set undodir=$HOME/.vimundo/
set undofile
set winwidth=83
set modeline
set hidden
set hlsearch

" Some webfonts don't handle this well which screws up ssh (hterm) on ChromeOS
set listchars=tab:+\ ,eol:¬,extends:>,precedes:<,trail:_
set showbreak=>

" map leader to space
let mapleader = " "

" Use a line cursor within insert mode and a block cursor everywhere else.
"
" Reference chart of values:
"   Ps = 0  -> blinking block.
"   Ps = 1  -> blinking block (default).
"   Ps = 2  -> steady block.
"   Ps = 3  -> blinking underline.
"   Ps = 4  -> steady underline.
"   Ps = 5  -> blinking bar (xterm).
"   Ps = 6  -> steady bar (xterm).
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"

" Switch between tabs
nnoremap <Leader>1 1gt
nnoremap <Leader>2 2gt
nnoremap <Leader>3 3gt
nnoremap <Leader>4 4gt
nnoremap <Leader>5 5gt
nnoremap <Leader>6 6gt
nnoremap <Leader>7 7gt
nnoremap <Leader>8 8gt
nnoremap <Leader>9 9gt

" Easy tab shortcuts
noremap <Leader>tn :tabnew<CR>
noremap <Leader>tc :tabclose<CR>
noremap <Leader>tm :tabmove<CR>
noremap <Leader>tp :tabprevious<CR>

" fuck the arrow keys
noremap <left> <nop>
noremap <up> <nop>
noremap <down> <nop>
noremap <right> <nop>

" fzf
noremap <Leader>ff :Files<CR>

" the F1 help menu can kick rocks
nmap <F1> <nop>

" Yank from current cursor position to end of line
map Y y$

" fat fingers be damned
command! W :w
command! Q :q

" colors
set t_Co=256
colorscheme badwolf
let &colorcolumn="80,".join(range(400,999),",")

""" Airline settings
" Set airline to use not use powerline fancy font symbols
let g:airline_symbols_ascii = 1

""" Autoswap
set title titlestring=
let g:autoswap_detect_tmux = 1

""" Indent-guides Settings
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_exclude_filetypes = ['help', 'nerdtree']
let g:indent_guides_start_level=2
let g:indent_guides_guide_size=1
let g:indent_guides_auto_colors = 0
au VimEnter,Colorscheme * :hi IndentGuidesOdd  ctermbg=238
au VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=236

""" shortcuts because I'm lazy
cnoreabbrev AR AirlineRefresh
cnoreabbrev SP set paste

""" Random filetype settings
au FileType python setlocal expandtab sw=4 sts=4 ts=8
au FileType toml setlocal expandtab sw=4 sts=4 ts=8
au FileType sh setlocal expandtab sw=4 sts=4 ts=8
au FileType yaml setlocal expandtab sw=2 sts=2 ts=4
au FileType ruby setlocal expandtab sw=2 sts=2 ts=4
au FileType go setlocal ts=4 sts=4 sw=4 noexpandtab

" Trailing whitespace override
" Only shown when not in insert mode so I don't go insane.
augroup trailing
    au!
    au InsertEnter * :set listchars-=trail:_
    au InsertLeave * :set listchars+=trail:_
augroup END

" coc.nvim settings
let g:coc_filetype_map = {
	\ 'yaml.ansible': 'ansible',
	\}

syntax on
