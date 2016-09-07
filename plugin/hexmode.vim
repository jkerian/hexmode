"============================================================================
"File:        hexmode.vim
"Description: vim plugin for on hex editing files, autoloaded with .bin or .hex files
"Origin:      http://vim.wikia.com/wiki/Improved_hex_editing
"             To manually switch between hex mode and text mode, `:Hexmode` will toggle
"
"WARNING: Be careful of switching manually inside a binary file. vim will
"         consider a file text by default and append a newline character
"============================================================================

if exists("g:loaded_hexmode_plugin")
    finish
endif

let g:loaded_hexmode_plugin = 1
" default auto hexmode file patterns
let g:hexmode_patterns = get(g:, 'hexmode_patterns', '*.bin,*.exe,*.so,*.jpg,*.jpeg,*.gif,*.png,*.pdf,*.tiff')
if !exists("g:hexmode_auto_open_binary_files")
    let g:hexmode_auto_open_binary_files = 0
endif

" ex command for toggling hex mode - define mapping if desired
command! -bar Hexmode call ToggleHex()

" helper function to toggle hex mode
function! ToggleHex()
    " hex mode should be considered a read-only operation
    " save values for modified and read-only for restoration later,
    " and clear the read-only flag for now
    let l:modified=&mod
    let l:oldreadonly=&readonly
    let &readonly=0
    let l:oldmodifiable=&modifiable
    let &modifiable=1
    if !exists("b:editHex") || !b:editHex
    " save old options
        let b:oldft=&ft
        let b:oldbin=&bin
        " set new options
        setlocal binary " make sure it overrides any textwidth, etc.
        let &ft="xxd"
        " set status
        let b:editHex=1
        " switch to hex editor
        silent %!xxd
    else
    " restore old options
        let &ft=b:oldft
        if !b:oldbin
            setlocal nobinary
        endif
        " set status
        let b:editHex=0
        " return to normal editing
        silent %!xxd -r
    endif
    " restore values for modified and read only state
    let &mod=l:modified
    let &readonly=l:oldreadonly
    let &modifiable=l:oldmodifiable
endfunction

function! IsBinary()
    if &binary
        return 1
    elseif executable('file')
        let file = system('file -ibL ' . shellescape(expand('%:p')))
        return file !~# 'inode/x-empty'
            \ && file !~# 'inode/fifo'
            \ && file =~# 'charset=binary'
    endif
    return 0
endfunction

" autocmds to automatically enter hex mode and handle file writes properly
if has("autocmd")
    " vim -b : edit binary using xxd-format!
    augroup Binary
        au!

        " set binary option for all binary files before reading them
        execute printf('au BufReadPre %s setlocal binary', g:hexmode_patterns)

        if g:hexmode_auto_open_binary_files
            au BufReadPre * let &binary = IsBinary() | let b:allow_hexmode = 1
        endif

        " gzipped help files show up as binary in (and only in) BufReadPost
        au BufReadPre */doc/*.txt.gz let b:allow_hexmode = 0

        " if on a fresh read the buffer variable is already set, it's wrong
        au BufReadPost *
            \ if exists('b:editHex') && b:editHex |
            \   let b:editHex = 0 |
            \ endif

        " convert to hex on startup for binary files automatically
        if g:hexmode_auto_open_binary_files
            au BufReadPost *
                \ if &binary && b:allow_hexmode | Hexmode | endif
        endif

        " When the text is freed, the next time the buffer is made active it will
        " re-read the text and thus not match the correct mode, we will need to
        " convert it again if the buffer is again loaded.
        au BufUnload *
            \ if getbufvar(expand("<afile>"), 'editHex') == 1 |
            \   call setbufvar(expand("<afile>"), 'editHex', 0) |
            \ endif

        " before writing a file when editing in hex mode, convert back to non-hex
        au BufWritePre *
            \ if exists("b:editHex") && b:editHex && &binary |
            \  let oldview = winsaveview() |
            \  let oldro=&ro | let &ro=0 |
            \  let oldma=&ma | let &ma=1 |
            \  undojoin |
            \  silent exe "%!xxd -r" |
            \  let &ma=oldma | let &ro=oldro |
            \  unlet oldma | unlet oldro |
            \  let &undolevels = &undolevels |
            \ endif

        " after writing a binary file, if we're in hex mode, restore hex mode
        au BufWritePost *
            \ if exists("b:editHex") && b:editHex && &binary |
            \  let oldro=&ro | let &ro=0 |
            \  let oldma=&ma | let &ma=1 |
            \  undojoin |
            \  silent exe "%!xxd" |
            \  exe "set nomod" |
            \  let &ma=oldma | let &ro=oldro |
            \  unlet oldma | unlet oldro |
            \  call winrestview(oldview) |
            \  let &undolevels = &undolevels |
            \ endif
    augroup END
endif
