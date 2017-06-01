" Automtic update ... it's slow, but meh
let g:spacevim_automatic_update = 1

" Here are some basic customizations, please refer to the ~/.SpaceVim.d/init.vim
" file for all possible options:
"let g:spacevim_default_indent = 3
let g:spacevim_max_column     = 80

" Change the default directory where all miscellaneous persistent files go.
" By default it is ~/.cache/vimfiles.
"let g:spacevim_plugin_bundle_dir = '~/.cache/vimfiles'

" set SpaceVim colorscheme
let g:spacevim_colorscheme = 'badwolf'

" Set plugin manager, you want to use, default is dein.vim
"let g:spacevim_plugin_manager = 'dein'  " neobundle or dein or vim-plug

" use space as `<Leader>`
"let mapleader = "\<space>"

" Set windows shortcut leader [Window], default is `s`
"let g:spacevim_windows_leader = 's'

" Set unite work flow shortcut leader [Unite], default is `f`
"let g:spacevim_unite_leader = 'f'

" By default, language specific plugins are not loaded. This can be changed
" with the following, then the plugins for go development will be loaded.
"call SpaceVim#layers#load('lang#go')

" loaded ui layer
"call SpaceVim#layers#load('ui')

" If there is a particular plugin you don't like, you can define this
" variable to disable them entirely:
"let g:spacevim_disabled_plugins=[
"\ ['junegunn/fzf.vim'],
"\ ]

" If you want to add some custom plugins, use these options:
"\ ['plasticboy/vim-markdown', {'on_ft' : 'markdown'}],
let g:spacevim_custom_plugins = [
\ ['vim-scripts/badwolf'],
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
