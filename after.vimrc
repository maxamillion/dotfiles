set norelativenumber
set number
set cursorline

" Needed because vim 7.4 yaml syntax is really slow and cpu intensive. This is a
" more simple and faster syntaxer.
Bundle 'stephpy/vim-yaml'

" Ansible
Bundle 'chase/vim-ansible-yaml'

colorscheme badwolf

" For sanity
let g:syntastic_check_on_wq = 0
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [], 'passive_filetypes': [] }

" For sphinx, the default is something else and it drives me nuts
let g:syntastic_rst_checkers = ['sphinx']

" Random filetypes
"
" asciidoc - *.adoc
au BufRead,BufNewFile *.adoc set filetype=asciidoc

" Set python just to be sure (in case vimified defaults change)
autocmd FileType python setlocal expandtab sw=4 sts=4 ts=8

" Set yaml to be 2 space tab width
autocmd FileType yaml setlocal expandtab sw=2 sts=2 ts=4

" Set ruby to be 2 space tab width
autocmd FileType ruby setlocal expandtab sw=2 sts=2 ts=4

" various bits of pymode are slow, turn off things we don't use
let g:pymode = 1
let g:pymode_indent = 1
let g:pymode_folding = 0
let g:pymode_motion = 1
let g:pymode_doc = 0
let g:pymode_virtualenv = 0
let g:pymode_breakpoint = 0
let g:pymode_run = 0
let g:pymode_syntax = 1
let g:pymode_syntax_slow_sync = 0
let g:pymode_rope = 0
let g:pymode_lint = 0
let g:pymode_lint_checkers = ['pyflakes', 'pep8']
let g:pymode_trim_whitespaces = 1
