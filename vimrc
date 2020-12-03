call plug#begin('~/.vim/plugged')
Plug 'Glench/Vim-Jinja2-Syntax'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'davidhalter/jedi-vim'
Plug 'ajh17/VimCompletesMe'
Plug 'sheerun/vim-polyglot'
Plug 'vim-airline/vim-airline'
Plug 'dense-analysis/ale'
Plug 'fatih/vim-go'
Plug 'sjl/badwolf'
Plug 'tpope/vim-endwise'
Plug 'gioele/vim-autoswap'
call plug#end()

set autoindent
set cursorline
set eol
set matchtime=2
set number
set numberwidth=3
set relativenumber
set relativenumber
set ruler
set showcmd
set showmatch
set undodir=$HOME/.vimundo/
set undofile
set winwidth=83

" Some webfonts don't handle this well which screws up ssh (hterm) on ChromeOS
set listchars=tab:+\ ,eol:¬,extends:>,precedes:<,trail:_
set showbreak=>

" fuck the arrow keys
noremap <left> <nop>
noremap <up> <nop>
noremap <down> <nop>
noremap <right> <nop>

" the F1 help menu can kick rocks
nmap <F1> <nop>

" Yank from current cursor position to end of line
map Y y$

command! W :w
command! Q :q

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

syntax on
