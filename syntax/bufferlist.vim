" Location: syntax/bufferlist.vim
" Maintainer: Yogesh Dhamija <yogeshdhamija@outlook.com>

if(exists("b:current_syntax"))
    finish
endif

" The text is :ls output, minus its trailing "line N". After the buffer
" number come five fixed flag columns -- unlisted, current/alternate,
" active/hidden, readonly, modified -- then the quoted name.
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

" Names in the form scheme://... -- terminals (term://), and buffers plugins
" make that are not files (oil://, fugitive://) -- so they stand out from the
" files around them. The scheme gets a group of its own. Anchored with a
" lookbehind, for the same reason as above: scanning resumes after the flags,
" where ^ can no longer match.
syntax match bufferListUrl /\%(^\s*\d\+.\{5} \)\@<="\a[[:alnum:]+.-]*:\/\/.*"/ contains=bufferListUrlScheme
syntax match bufferListUrlScheme /"\zs\a[[:alnum:]+.-]*:\/\// contained

" The flags use the same groups fzf.vim uses for the same markers, so the
" list looks familiar. The buffer numbers are greyed out like the hints, to
" keep the eye on the names.
highlight default link bufferListNumber Comment
highlight default link bufferListUnlisted Comment
highlight default link bufferListCurrent Conditional
highlight default link bufferListAlternate Conditional
highlight default link bufferListActive Type
highlight default link bufferListReadonly Constant
highlight default link bufferListModified Exception
highlight default link bufferListNoName Comment
highlight default link bufferListUrl Identifier
highlight default link bufferListUrlScheme Special

let b:current_syntax = "bufferlist"
