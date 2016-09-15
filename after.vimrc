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

" pymode rope is stupid slow, just disable it
let g:pymode_rope=0
