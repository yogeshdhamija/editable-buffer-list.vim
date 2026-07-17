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

function! s:Listed() abort
    return sort(map(getbufinfo({'buflisted': 1}), 'v:val["bufnr"]'), 'n')
endfunction

" 0 means "no buffer on this line": buffer numbers start at 1.
function! s:ParseBufnr(line) abort
    return str2nr(matchstr(a:line, '^\s*\zs\d\+\ze\%(\s\|$\)'))
endfunction

function! s:Format(bufnr) abort
    let l:name = bufname(a:bufnr)
    let l:display = empty(l:name) ? '[No Name]' : fnamemodify(l:name, ':~:.')
    let l:origin = a:bufnr == get(b:, 'editable_buffer_list_origin', 0) ? '%' : ' '
    let l:modified = getbufvar(a:bufnr, '&modified') ? '+' : ' '
    return printf('%3d %s%s %s', a:bufnr, l:origin, l:modified, l:display)
endfunction

function! s:Render() abort
    let l:lines = map(s:Listed(), 's:Format(v:val)')
    if(empty(l:lines))
        let l:lines = ['']
    endif
    if(l:lines !=# getline(1, '$'))
        call setline(1, l:lines)
        if(line('$') > len(l:lines))
            call deletebufline('%', len(l:lines) + 1, '$')
        endif
    endif
    " So bufhidden=wipe can discard the list without E89 when it's abandoned.
    setlocal nomodified
endfunction

function! s:Apply() abort
    let l:visible = {}
    for l:line in getline(1, '$')
        let l:nr = s:ParseBufnr(l:line)
        if(l:nr)
            let l:visible[l:nr] = 1
        endif
    endfor

    let l:errors = []
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

    " Redraw from reality. This converges: the redraw fires one more
    " TextChanged, which then finds text and reality already agreeing. It is
    " also what puts a line back when its buffer refused to unload.
    call s:Render()
    if(!empty(l:errors))
        echohl WarningMsg
        echomsg join(l:errors, ' | ')
        echohl None
    endif
endfunction

function! editableBufferList#Open() abort
    if(!exists('b:editable_buffer_list_origin'))
        let l:origin = bufnr('%')
        enew
        setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap
        let b:editable_buffer_list_origin = l:origin
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
    call s:Render()
    let l:at = index(s:Listed(), b:editable_buffer_list_origin)
    call cursor(l:at >= 0 ? l:at + 1 : 1, 1)
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
