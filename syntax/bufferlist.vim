" Location: syntax/bufferlist.vim
" Maintainer: Yogesh Dhamija <yogeshdhamija@outlook.com>

if(exists("b:current_syntax"))
    finish
endif

syntax match bufferListNumber /^\s*\d\+/
syntax match bufferListOrigin /^\s*\d\+ \zs%/
syntax match bufferListModified /^\s*\d\+ .\zs+/
syntax match bufferListNoName /\[No Name\]$/

" Same groups fzf.vim uses for the same markers, so the list looks familiar.
highlight default link bufferListNumber Number
highlight default link bufferListOrigin Conditional
highlight default link bufferListModified Exception
highlight default link bufferListNoName Comment

let b:current_syntax = "bufferlist"
