" Automtic update ... it's slow, but meh
let g:spacevim_automatic_update = 1

let g:spacevim_default_indent = 4
let g:spacevim_max_column     = 80
let g:spacevim_enable_neomake = 0
let g:spacevim_snippet_engine = 'ultisnips'
let g:spacevim_lint_on_save = 0
let g:spacevim_lint_on_the_fly = 0


" Custom plugins
"\ ['plasticboy/vim-markdown', {'on_ft' : 'markdown'}],
let g:spacevim_custom_plugins = [
\ ['chase/vim-ansible-yaml'],
\ ['vim-syntastic/syntastic'],
\ ]

""" 
""" Syntastic Stuff 
let g:syntastic_check_on_wq = 0
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [], 'passive_filetypes': [] }
" For sphinx, the default is something else and it drives me nuts
let g:syntastic_rst_checkers = ['sphinx']
" Syntastic shortcuts because I'm lazy
cnoreabbrev SC w <bar> SyntasticCheck
cnoreabbrev SR SyntasticReset

" Random filetype stuff
"
" asciidoc - *.adoc
au BufRead,BufNewFile *.adoc set filetype=asciidoc

" Set python just to be sure (in case vimified defaults change)
autocmd FileType python setlocal expandtab sw=4 sts=4 ts=8

" Set yaml to be 2 space tab width
autocmd FileType yaml setlocal expandtab sw=2 sts=2 ts=4

" Set ruby to be 2 space tab width
autocmd FileType ruby setlocal expandtab sw=2 sts=2 ts=4

" Set golang stuff
autocmd FileType go setlocal ts=4 sts=4 sw=4 noexpandtab

" Set column marker
set colorcolumn=80

" Turn off the damn mouse
set mouse=""

" Set gruvbox contrast
let g:gruvbox_contrast_dark = 'hard'
