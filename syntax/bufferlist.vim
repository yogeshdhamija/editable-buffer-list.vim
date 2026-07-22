" Location: syntax/bufferlist.vim
" Maintainer: Yogesh Dhamija <yogeshdhamija@outlook.com>

if(exists("b:current_syntax"))
    finish
endif

" The text is :ls output. After the buffer number come five fixed flag
" columns -- unlisted, current/alternate, active/hidden, readonly, modified --
" then the quoted name and a trailing "line N".
" The number and the flags have to be one match with the pieces contained
" inside it: matching them separately gets only the number highlighted,
" because the engine resumes scanning past that match and never retries the
" line-anchored flag patterns. Inside a span this narrow each flag character
" is unambiguous, so the contained items need no anchoring of their own.
syntax match bufferListEntry /^\s*\d\+.\{5}/ contains=bufferListNumber,bufferListUnlisted,bufferListCurrent,bufferListAlternate,bufferListActive,bufferListReadonly,bufferListModified
syntax match bufferListNumber /\d\+/ contained
syntax match bufferListUnlisted /u/ contained
syntax match bufferListCurrent /%/ contained
syntax match bufferListAlternate /#/ contained
syntax match bufferListActive /[ah]/ contained
syntax match bufferListReadonly /[-=RF?]/ contained
syntax match bufferListModified /[+x]/ contained

syntax match bufferListNoName /"\[No Name\]"/
syntax match bufferListLnum /\<line \d\+$/

" Same groups fzf.vim uses for the same markers, so the list looks familiar.
highlight default link bufferListNumber Number
highlight default link bufferListUnlisted Comment
highlight default link bufferListCurrent Conditional
highlight default link bufferListAlternate Conditional
highlight default link bufferListActive Type
highlight default link bufferListReadonly Constant
highlight default link bufferListModified Exception
highlight default link bufferListNoName Comment
highlight default link bufferListLnum Comment

let b:current_syntax = "bufferlist"
