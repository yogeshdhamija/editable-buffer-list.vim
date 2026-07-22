" Location: autoload/editableBufferList.vim
" Maintainer: Yogesh Dhamija <yogeshdhamija@outlook.com>

if(exists("g:autoloaded_editable_buffer_list"))
    finish
endif
let g:autoloaded_editable_buffer_list = 1

" The list is a plain modifiable scratch buffer, so anything that edits text
" works on it: dd, d2j, Vd, :g/foo/d, u. After every change the visible lines
" are diffed against the real buffer list -- a line that disappeared unloads
" its buffer, a line that came back (undo) relists it. Only the leading buffer
" number is ever read back from the text; everything else is redrawn from
" reality, so a mangled line is swept away rather than misread.
"
" The text itself is :ls output, verbatim.

function! s:Listed() abort
    return sort(map(getbufinfo({'buflisted': 1}), 'v:val["bufnr"]'), 'n')
endfunction

" 0 means "no buffer on this line": buffer numbers start at 1.
function! s:ParseBufnr(line) abort
    return str2nr(matchstr(a:line, '^\s*\zs\d\+\ze\%(\s\|$\)'))
endfunction

" Where to run :ls for a list. Its own window, because that is what makes the
" markers mean what they say: the list buffer is 'nobuflisted', so it never
" appears in its own output and no line is ever '%', and '#' is that window's
" alternate file -- the buffer the list replaced, which does not move when
" some other window changes buffers. 0 means "nowhere to run it".
function! s:LsWindow(list_buf) abort
    if(!exists('*win_execute'))
        " No way to reach another window's context; only the focused list can
        " be drawn, which is where :ls would be evaluated anyway.
        return a:list_buf == bufnr('%') ? win_getid() : 0
    endif
    return get(win_findbuf(a:list_buf), 0, 0)
endfunction

function! s:Capture(winid) abort
    if(exists('*win_execute'))
        return win_execute(a:winid, 'ls')
    endif
    let l:out = ''
    redir => l:out
    silent ls
    redir END
    return l:out
endfunction

" a:1 is a buffer to leave out even though :ls still reports it -- see the
" BufDelete autocmd below.
function! s:Render(list_buf, ...) abort
    let l:winid = s:LsWindow(a:list_buf)
    if(!l:winid)
        return
    endif
    " :ls leads with a blank line. Left in, it would be a list entry carrying
    " no buffer number, shifting every real entry down one.
    let l:lines = filter(split(s:Capture(l:winid), "\n"), 'v:val !=# ""')
    let l:skip = a:0 ? a:1 : 0
    if(l:skip)
        " String concatenation for older Vim, which has no lambdas.
        call filter(l:lines, 's:ParseBufnr(v:val) != ' . l:skip)
    endif
    if(empty(l:lines))
        let l:lines = ['']
    endif
    let l:old_lines = getbufline(a:list_buf, 1, '$')
    if(l:lines !=# l:old_lines)
        call setbufline(a:list_buf, 1, l:lines)
        if(len(l:old_lines) > len(l:lines))
            call deletebufline(a:list_buf, len(l:lines) + 1, '$')
        endif
    endif
    " So bufhidden=wipe can discard the list without E89 when it's abandoned.
    call setbufvar(a:list_buf, '&modified', 0)
endfunction

function! s:UpdateAll(...) abort
    " Prevent global events from overriding while the user's buffer edits are still processing
    if get(g:, 'editable_buffer_list_applying', 0)
        return
    endif

    let l:skip = a:0 ? a:1 : 0
    " Find all buffers acting as a buffer list
    for l:list_buf in filter(range(1, bufnr('$')), 'getbufvar(v:val, "&filetype") ==# "bufferlist"')
        call s:Render(l:list_buf, l:skip)
    endfor
endfunction

augroup EditableBufferListGlobal
    autocmd!
    " Trigger background list refresh on all relevant global buffer lifecycle and focus events
    autocmd BufAdd,BufFilePost,BufEnter,BufWritePost * call s:UpdateAll()
    " These two fire *before* the buffer leaves the list, and Vim has no
    " matching "after" event, so :ls here still reports the buffer that is on
    " its way out. Rather than defer the redraw until it is really gone, drop
    " that one buffer from this redraw: <abuf> names it exactly. The event
    " only fires once the delete is actually going through, so a refused
    " :bdelete never reaches this and never hides a line that is staying.
    autocmd BufDelete,BufWipeout * call s:UpdateAll(str2nr(expand('<abuf>')))
augroup END

function! s:Apply() abort
    let l:visible = {}
    for l:line in getline(1, '$')
        let l:nr = s:ParseBufnr(l:line)
        if(l:nr)
            let l:visible[l:nr] = 1
        endif
    endfor

    let l:errors = []
    
    " Pause auto-updates while manually applying changes from inside the list
    let g:editable_buffer_list_applying = 1
    for l:b in s:Listed()
        if(!has_key(l:visible, l:b))
            try
                execute 'bdelete' l:b
            catch
                call add(l:errors, matchstr(v:exception, 'E\d\+.*'))
            endtry
        endif
    endfor

    " This is what makes plain u work without a separate undo stack: undo
    " brings the deleted line back, and since :bdelete only unlists (the
    " buffer still exists), relisting it restores the entry.
    for l:nr in keys(l:visible)
        let l:b = str2nr(l:nr)
        if(bufexists(l:b) && !buflisted(l:b))
            call setbufvar(l:b, '&buflisted', 1)
        endif
    endfor
    let g:editable_buffer_list_applying = 0

    " Redraw from reality. This converges: the redraw fires one more
    " TextChanged, which then finds text and reality already agreeing. It is
    " also what puts a line back when its buffer refused to unload.
    call s:Render(bufnr('%'))
    if(!empty(l:errors))
        echohl WarningMsg
        echomsg join(l:errors, ' | ')
        echohl None
    endif
endfunction

function! editableBufferList#Open() abort
    " Re-entrancy: :BufferList from inside a list redraws it in place rather
    " than nesting a second one.
    if(&filetype !=# 'bufferlist')
        " enew makes the buffer this window was showing its alternate, which
        " is what puts the '#' on it.
        enew
        setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap
        " Purely cosmetic (statusline); harmless to skip if the name is taken
        " because another list window is open.
        silent! execute 'file' fnameescape('[Buffer List]')
        setlocal filetype=bufferlist
        augroup EditableBufferList
            autocmd! * <buffer>
            autocmd TextChanged,InsertLeave <buffer> call s:Apply()
        augroup END
        nnoremap <buffer> <CR> <Cmd>call editableBufferList#OpenUnderCursor()<CR>
    endif
    call s:Render(bufnr('%'))
    " Start on '#', the buffer this window was showing. Line 1 if it is gone.
    call cursor(max([1, match(getline(1, '$'), '^\s*\d\+ #') + 1]), 1)
endfunction

function! editableBufferList#OpenUnderCursor() abort
    let l:b = s:ParseBufnr(getline('.'))
    if(!l:b || !bufexists(l:b))
        echo 'No buffer under cursor'
        return
    endif
    " keepalt so # still points at the buffer this window had before the list
    " replaced it -- CTRL-^ after picking behaves as if the list was never
    " there.
    execute 'keepalt buffer' l:b
endfunction
