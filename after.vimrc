set norelativenumber
set number
set cursorline

colorscheme badwolf

let g:syntastic_check_on_wq = 0

" Random filetypes
"
" asciidoc - *.adoc
au BufRead,BufNewFile *.adoc set filetype=asciidoc
