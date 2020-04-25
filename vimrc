call plug#begin('~/.vim/plugged')
Plug 'Glench/Vim-Jinja2-Syntax'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'davidhalter/jedi-vim'
Plug 'ajh17/VimCompletesMe'
Plug 'sheerun/vim-polyglot'
Plug 'vim-airline/vim-airline'
Plug 'vim-syntastic/syntastic'
Plug 'sjl/badwolf'
Plug 'tpope/vim-endwise'
Plug 'pearofducks/ansible-vim'
call plug#end()

set undofile
set undodir=$HOME/.vimundo/
set relativenumber
set numberwidth=3
set winwidth=83
set ruler
set showcmd
set matchtime=2
set autoindent
set relativenumber
set number
set cursorline
set showmatch
set eol

" Some webfonts don't handle this well which screws up ssh (hterm) on ChromeOS
set showbreak=>
set listchars=tab:+\ ,eol:¬,extends:>,precedes:<,trail:_

" fuck the arrow keys
noremap <left> <nop>
noremap <up> <nop>
noremap <down> <nop>
noremap <right> <nop>

" Yank from current cursor position to end of line
map Y y$

command! W :w
command! Q :q

colorscheme badwolf

let python_highlight_all = 1
let &colorcolumn="80,".join(range(400,999),",")

""" Syntastic
let g:syntastic_check_on_wq = 0
let g:syntastic_enable_signs=1
let g:syntastic_auto_loc_list=1

" For sphinx, the default is something else and it drives me nuts
let g:syntastic_rst_checkers = ['sphinx']

""" Airline settings
" Set airline to use not use powerline fancy font symbols
let g:airline_symbols_ascii = 1


""" Indent-guides Settings
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_exclude_filetypes = ['help', 'nerdtree']
let g:indent_guides_start_level=2
let g:indent_guides_guide_size=1
let g:indent_guides_auto_colors = 0
au VimEnter,Colorscheme * :hi IndentGuidesOdd  ctermbg=238
au VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=236

""" shortcuts because I'm lazy
cnoreabbrev SC w <bar> SyntasticCheck
cnoreabbrev SR SyntasticReset
cnoreabbrev AR AirlineRefresh
cnoreabbrev SP set paste

""" Random filetype settings
au BufRead,BufNewFile *.adoc set filetype=asciidoc
au BufRead,BufNewFile *.j2,*.jinja,*.jinja2  set ft=jinja
au BufRead,BufNewFile */playbooks/*.yml,*/roles/*.yml,*/ansible_collections/*.yml set filetype=yaml.ansible
au FileType python setlocal expandtab sw=4 sts=4 ts=8
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
