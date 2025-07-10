call plug#begin('~/.vim/plugged')
Plug 'Glench/Vim-Jinja2-Syntax'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'dense-analysis/ale'
Plug 'sheerun/vim-polyglot'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'fatih/vim-go'
Plug 'rust-lang/rust.vim'
Plug 'rhysd/vim-healthcheck'
Plug 'sainnhe/sonokai'
Plug 'tpope/vim-endwise'
Plug 'gioele/vim-autoswap'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'Exafunction/windsurf.vim', { 'branch': 'main' }
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

set encoding=utf-8
" Some servers have issues with backup files, see #649
set nobackup
set nowritebackup

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved
set signcolumn=yes

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

" Set ft=yaml.ansible
noremap <Leader>sa :set ft=yaml.ansible<CR>

" Easy window navigation
noremap <Leader>h <C-w>h
noremap <Leader>j <C-w>j
noremap <Leader>k <C-w>k
noremap <Leader>l <C-w>l

" fuck the arrow keys
noremap <left> <nop>
noremap <up> <nop>
noremap <down> <nop>
noremap <right> <nop>

" fzf
noremap <Leader>ff :Files<CR>
noremap <Leader>fg :Rg<CR>
noremap <Leader>fl :Lines<CR>
noremap <Leader>gf :GFiles<CR>

" windsurf suggestion cycling - only accept with Ctrl-g
imap <script><silent><nowait><expr> <C-g> codeium#Accept()
imap <C-j>   <Cmd>call codeium#CycleCompletions(1)<CR>
imap <C-k>   <Cmd>call codeium#CycleCompletions(-1)<CR>
let g:codeium_disable_bindings = 1

" the F1 help menu can kick rocks
nmap <F1> <nop>

" Yank from current cursor position to end of line
map Y y$

" fat fingers be damned
command! W :w
command! Q :q

" colors
set t_Co=256
colorscheme sonokai

" colorcolumn
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
au FileType vim setlocal expandtab sw=2 sts=2 ts=4
au FileType go setlocal ts=4 sts=4 sw=4 noexpandtab

" Trailing whitespace override
" Only shown when not in insert mode so I don't go insane.
augroup trailing
    au!
    au InsertEnter * :set listchars-=trail:_
    au InsertLeave * :set listchars+=trail:_
augroup END

" ALE
nmap gd <Plug>ALEGoToDefinition<cr>
nmap ge <Plug>ALEDetail<cr>
nmap gr <Plug>ALEFindReferences<cr>
nmap gk <Plug>ALEDocumentation<cr>

let g:ale_completion_enabled = 1
let g:ale_completion_autoimport = 1
let g:ale_completion_delay = 0
let g:ale_completion_max_suggestions = 50
let g:ale_sign_error = '>>'
let g:ale_sign_warning = 'WW'
let g:ale_linters = {
\   'bash': ['bash-language-server'],
\}


" Enable omni completion
set omnifunc=ale#completion#OmniFunc
set completeopt=menu,menuone,noselect

" Auto-trigger completion as you type
augroup ALECompletion
  autocmd!
  autocmd TextChangedI * if pumvisible() == 0|pclose|call feedkeys("\<C-n>", "n")|endif
augroup END

" Use Ctrl-y to accept completion, disable Tab from cycling
inoremap <expr> <C-y> pumvisible() ? "\<C-y>" : "\<C-y>"
inoremap <expr> <Tab> pumvisible() ? "\<Tab>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<S-Tab>" : "\<S-Tab>"

" Sync clipboard with system clipboard for Wayland
if executable('wl-copy')
  augroup WaylandClipboard
    autocmd!
    autocmd TextYankPost * if v:event.operator ==# 'y' | call system('wl-copy', @") | endif
  augroup END
endif

syntax on
