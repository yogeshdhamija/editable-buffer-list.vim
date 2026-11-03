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
" The text itself is :ls output, sorted by name and without the "line N" at
" the end of each line -- see s:Tidy.

function! s:Listed() abort
    return sort(map(getbufinfo({'buflisted': 1}), 'v:val["bufnr"]'), 'n')
endfunction

" 0 means "no buffer on this line": buffer numbers start at 1.
function! s:ParseBufnr(line) abort
    return str2nr(matchstr(a:line, '^\s*\zs\d\+\ze\%(\s\|$\)'))
endfunction

" A line of :ls output up to the closing quote of the name, which drops the
" padding and the "line N" after it. That number is the cursor line Vim last
" remembered for the buffer, not where its window's cursor is, so it is
" usually stale. Cutting at the quote rather than matching "line" also copes
" with a translated message. A line in some other shape is left alone.
function! s:StripLnum(line) abort
    let l:kept = matchstr(a:line, '^\s*\d\+.\{5} ".*"')
    return empty(l:kept) ? a:line : l:kept
endfunction

" The quoted name, ignoring case, so that README and readme sort together.
function! s:SortKey(line) abort
    return tolower(matchstr(a:line, '^\s*\d\+.\{5}\zs.*'))
endfunction

" Equal names -- several [No Name] buffers -- fall back to buffer number, so
" the order never depends on whether this Vim's sort() is stable.
function! s:CompareNames(a, b) abort
    let l:a = s:SortKey(a:a)
    let l:b = s:SortKey(a:b)
    if(l:a ==# l:b)
        return s:ParseBufnr(a:a) - s:ParseBufnr(a:b)
    endif
    return l:a <# l:b ? -1 : 1
endfunction

" :ls output as the list shows it: in alphabetical order of name, with no
" line numbers. Only the leading buffer number is ever read back, so the
" order is free to be anything.
function! s:Tidy(lines) abort
    return sort(map(a:lines, 's:StripLnum(v:val)'), function('s:CompareNames'))
endfunction

" Where to run :ls for a list. Its own window, because that is what makes the
" markers mean what they say: the list buffer is 'nobuflisted', so it never
" appears in its own output and no line is ever '%', and '#' is that window's
" alternate file -- the buffer the list replaced, which does not move when
" some other window changes buffers. 0 means "nowhere to run it".
" Whether no window is showing this buffer.
function! s:Hidden(buf) abort
    if(exists('*win_findbuf'))
        return empty(win_findbuf(a:buf))
    endif
    " Older Vim can only see the current tab page, so a list parked in another
    " tab reads as hidden and gets reused. The cost is two windows sharing one
    " list buffer -- and so disagreeing about '#' -- not a wrong list.
    return bufwinnr(a:buf) == -1
endfunction

" An abandoned list to take over, or 0. 'bufhidden' is hide rather than wipe
" so that jumping away leaves the list intact to jump back to (a wiped buffer
" has its jumplist entries dropped, so CTRL-O would skip straight past it).
" That means abandoned lists accumulate unless they are reused, which is what
" this is for. Lists still on screen are left alone so that each window keeps
" its own: '%' and '#' are per-window, and one buffer cannot show both.
function! s:ReusableList() abort
    for l:b in filter(range(1, bufnr('$')), 'getbufvar(v:val, "&filetype") ==# "bufferlist"')
        if(s:Hidden(l:b))
            return l:b
        endif
    endfor
    return 0
endfunction

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

" The hints: what the keys do, and what the flags in front of each name mean.
" They are virtual text above line 1 -- an extmark in Neovim, a text property
" in Vim -- so they are not part of the buffer: they cannot be edited,
" deleted or yanked, and are never read back as an entry. Vim got text above
" a line in 9.0.0438, but it did not work with 'nowrap' until 9.0.0451.
" Anything older just goes without.
let s:hints_supported = has('nvim-0.6') || (has('textprop') && has('patch-9.0.0451'))

" Linked here rather than in the syntax file: they have to exist even with
" syntax off, since Vim refuses a property type with an unknown highlight.
" A colorscheme clears links like these, hence the autocmd below.
function! s:DefineHighlights() abort
    highlight default link bufferListHint Comment
    highlight default link bufferListHintKey Special
endfunction
call s:DefineHighlights()

if(has('nvim'))
    let s:ns = nvim_create_namespace('editable-buffer-list')
elseif(s:hints_supported && empty(prop_type_get('bufferListHint')))
    call prop_type_add('bufferListHint', {'highlight': 'bufferListHint'})
endif

" What each :ls flag means, in the order of its columns, as [key, flag,
" meaning, highlight group]. The groups are the syntax file's, so a flag in
" the legend is colored the same as in the list. 'unloaded' is not a
" character: it is the a/h column left blank.
let s:flag_meanings = [
    \ ['u',        'u', 'unlisted',             'bufferListUnlisted'],
    \ ['%',        '%', 'current',              'bufferListCurrent'],
    \ ['#',        '#', 'alternate',            'bufferListAlternate'],
    \ ['a',        'a', 'active',               'bufferListActive'],
    \ ['h',        'h', 'hidden',               'bufferListActive'],
    \ ['unloaded', '',  'no a or h = unloaded', ''],
    \ ['-',        '-', 'not modifiable',       'bufferListReadonly'],
    \ ['=',        '=', 'read-only',            'bufferListReadonly'],
    \ ['R',        'R', 'running terminal',     'bufferListReadonly'],
    \ ['F',        'F', 'finished terminal',    'bufferListReadonly'],
    \ ['?',        '?', 'empty terminal',       'bufferListReadonly'],
    \ ['+',        '+', 'modified',             'bufferListModified'],
    \ ['x',        'x', 'read errors',          'bufferListModified'],
    \ ]

let s:sep = [' | ', 'bufferListHint']

" The hints, as lines of [text, highlight group] chunks -- Neovim's
" virt_lines format. First that the list is live, then what the keys do,
" then what the flags in a:lines, which is :ls output, mean. Only the flags
" that are there: one entry for every flag that could turn up would be too
" long to read.
function! s:HintLines(lines, width) abort
    let l:live = [
        \ [['see ', 'bufferListHint'], [':h :BufferList', 'bufferListHintKey']],
        \ [['Updates Live!', 'bufferListHint']],
        \ ]
    let l:delete = get(g:, 'editable_buffer_list_delete_command', 'bdelete')
    let l:keys = [
        \ [['<CR>', 'bufferListHintKey'], [' to open', 'bufferListHint']],
        \ [['delete line', 'bufferListHintKey'], [' to :' . l:delete, 'bufferListHint']],
        \ [['u', 'bufferListHintKey'], [' to undo', 'bufferListHint']],
        \ ]

    let l:present = {}
    for l:line in a:lines
        " :ls prints the number, then exactly five flag columns.
        let l:flags = matchstr(l:line, '^\s*\d\+\zs.\{5}')
        for l:flag in split(l:flags, '\zs')
            let l:present[l:flag] = 1
        endfor
        if(strlen(l:flags) == 5 && l:flags[2] ==# ' ')
            let l:present['unloaded'] = 1
        endif
    endfor
    let l:legend = []
    for [l:key, l:flag, l:meaning, l:group] in s:flag_meanings
        if(has_key(l:present, l:key))
            call add(l:legend, empty(l:flag)
                \ ? [[l:meaning, 'bufferListHint']]
                \ : [[l:flag, l:group], [' = ' . l:meaning, 'bufferListHint']])
        endif
    endfor

    let l:hints = s:Wrap(l:live, a:width) + s:Wrap(l:keys, a:width)
    if(!empty(l:legend))
        call extend(l:hints, s:Wrap(l:legend, a:width))
    endif
    return l:hints
endfunction

" Lays a:items -- each a list of chunks -- out in as few lines as fit
" a:width, with s:sep between them. Neither editor wraps a virtual line, it
" is cut off at the edge of the window, and losing the end of the legend that
" way would leave some flag unexplained. An item too wide for a line of its
" own is still cut off.
function! s:Wrap(items, width) abort
    let l:lines = []
    " Wide enough that the first item starts a line.
    let l:used = a:width
    for l:item in a:items
        let l:item_width = strdisplaywidth(join(map(copy(l:item), 'v:val[0]'), ''))
        let l:with_sep = strdisplaywidth(s:sep[0]) + l:item_width
        if(l:used + l:with_sep > a:width)
            call add(l:lines, copy(l:item))
            let l:used = l:item_width
        else
            call extend(l:lines[-1], [s:sep] + l:item)
            let l:used += l:with_sep
        endif
    endfor
    return l:lines
endfunction

" Cleared and redrawn whole every time. Besides being simple, that matters
" in Vim, where a property belongs to its line: dd on line 1 takes the hints
" with it, and undo brings that line back with them still attached, next to
" the ones redrawn in the meantime.
function! s:DrawHints(list_buf, lines, winid) abort
    if(!s:hints_supported)
        return
    endif
    let l:hints = []
    if(get(g:, 'editable_buffer_list_hints', 1))
        " The hints start where the text does, after any number or sign
        " column.
        let l:info = get(getwininfo(a:winid), 0, {})
        let l:width = get(l:info, 'width', winwidth(0)) - get(l:info, 'textoff', 0)
        let l:hints = s:HintLines(a:lines, l:width)
    endif
    if(has('nvim'))
        call nvim_buf_clear_namespace(a:list_buf, s:ns, 0, -1)
        if(!empty(l:hints))
            call nvim_buf_set_extmark(a:list_buf, s:ns, 0, 0, {'virt_lines': l:hints, 'virt_lines_above': v:true})
        endif
        " The number of lines may have changed. win_execute keeps this
        " script's context, so s: resolves in there.
        call win_execute(a:winid, 'call s:RevealHints()')
        return
    endif
    call prop_remove({'type': 'bufferListHint', 'bufnr': a:list_buf, 'all': 1})
    " One color per line: a text property has only the one highlight.
    for l:chunks in l:hints
        call prop_add(1, 0, {'type': 'bufferListHint', 'bufnr': a:list_buf, 'text_align': 'above',
            \ 'text': join(map(copy(l:chunks), 'v:val[0]'), '')})
    endfor
endfunction

" Neovim draws lines above line 1 as filler, like diff mode's, and shows
" them only once the window is scrolled up into them -- which neither opening
" the list nor gg does. So scroll it there whenever the top of the list is
" on screen. Vim draws them as part of line 1 and needs none of this.
function! s:RevealHints() abort
    if(!has('nvim') || line('w0') != 1)
        return
    endif
    let l:marks = nvim_buf_get_extmarks(0, s:ns, 0, 0, {'details': v:true})
    let l:height = empty(l:marks) ? 0 : len(get(l:marks[0][3], 'virt_lines', []))
    if(winsaveview().topfill != l:height)
        call winrestview({'topfill': l:height})
    endif
endfunction

" a:1 is a buffer to leave out even though :ls still reports it -- see the
" BufDelete autocmd below.
function! s:Render(list_buf, ...) abort
    " Jumping to a buffer relists it, so CTRL-O back into the list undoes the
    " 'nobuflisted' it was created with -- and a listed list shows up in its
    " own output, which is exactly what that setting is there to prevent.
    " Reasserting it here catches that on the BufEnter the jump fires, before
    " the render below can draw the list a line for itself.
    call setbufvar(a:list_buf, '&buflisted', 0)
    let l:winid = s:LsWindow(a:list_buf)
    if(!l:winid)
        return
    endif
    " :ls leads with a blank line. Left in, it would be a list entry carrying
    " no buffer number, shifting every real entry down one.
    let l:lines = s:Tidy(filter(split(s:Capture(l:winid), "\n"), 'v:val !=# ""'))
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
    call s:DrawHints(a:list_buf, l:lines, l:winid)
    " Every redraw would otherwise leave the list looking dirty, and :bdelete
    " on it would fail with E89. Nothing is ever lost by clearing this: the
    " text is regenerated from the real buffer list on the next render.
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

" Redraws the lists if any of them has a:buf's '+' flag wrong. Checking
" first is what makes running this after every change in Vim affordable: it
" reruns :ls only when the flag would actually change, not per keystroke.
function! s:FollowModified(buf) abort
    " A list's own edits are for its TextChanged to apply. A list never shows
    " itself, so this would usually find nothing to do anyway -- but a line
    " being typed into it can look like an entry, and a redraw would wipe it.
    if(getbufvar(a:buf, '&filetype') ==# 'bufferlist')
        return
    endif
    let l:modified = getbufvar(a:buf, '&modified')
    for l:list_buf in filter(range(1, bufnr('$')), 'getbufvar(v:val, "&filetype") ==# "bufferlist"')
        let l:lines = getbufline(l:list_buf, 1, '$')
        let l:i = match(l:lines, '^\s*' . a:buf . '\>')
        " '+' is the fifth flag column.
        if(l:i >= 0 && (l:lines[l:i] =~# '^\s*\d\+.\{4}+') != l:modified)
            call s:UpdateAll()
            return
        endif
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
    " For the '+' flag: editing a buffer in another window fires none of the
    " above. Neovim has an event for 'modified' changing; Vim does not, so it
    " has to look after every change.
    if(exists('##BufModifiedSet'))
        autocmd BufModifiedSet * call s:FollowModified(str2nr(expand('<abuf>')))
    else
        autocmd TextChanged,TextChangedI * call s:FollowModified(bufnr('%'))
    endif
    autocmd ColorScheme * call s:DefineHighlights()
    " The hints are laid out to fit the window, so lay them out again when it
    " changes size.
    autocmd VimResized * call s:UpdateAll()
    if(exists('##WinResized'))
        autocmd WinResized * call s:UpdateAll()
    endif
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
    " Looked up on every apply rather than once at load, so setting it after
    " the plugin has loaded still takes effect.
    let l:delete = get(g:, 'editable_buffer_list_delete_command', 'bdelete')

    " Pause auto-updates while manually applying changes from inside the list
    let g:editable_buffer_list_applying = 1
    for l:b in s:Listed()
        if(!has_key(l:visible, l:b))
            try
                execute l:delete l:b
            catch
                call add(l:errors, matchstr(v:exception, 'E\d\+.*'))
            endtry
        endif
    endfor

    " This is what makes plain u work without a separate undo stack: undo
    " brings the deleted line back, and since :bdelete only unlists (the
    " buffer still exists), relisting it restores the entry. A configured
    " delete command has to leave buffers existing for the same reason.
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
    "
    " A delete command that moves into other windows (vim-bbye's does, to
    " switch them off the buffer) ends the undo block the edit was in, which
    " would make this redraw an undo step of its own: u would then undo the
    " redraw rather than the edit. undojoin folds it back in. It is refused
    " right after an undo or redo, which have no edit to fold it into anyway.
    try
        undojoin
    catch /E790/
    endtry
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
        let l:reuse = s:ReusableList()
        if(l:reuse)
            " Like enew below, :buffer makes the buffer this window was
            " showing its alternate. The list's own mappings, autocmds and
            " options came with the buffer, which was hidden rather than
            " wiped, so there is nothing to set up again.
            execute 'buffer' l:reuse
        else
            " enew makes the buffer this window was showing its alternate,
            " which is what puts the '#' on it.
            enew
            " Deliberately 'nobuflisted'. Listing it would put the list in its
            " own output, and deleting that line -- with dd, or :%d meaning
            " "close everything" -- would make s:Apply :bdelete the list from
            " inside the list's own TextChanged autocmd, leaving a stray
            " buffer holding stale list text. It would also join :bufdo and
            " the :bnext rotation, and :mksession would write a `badd
            " [Buffer List]` that restores as a bogus empty file.
            setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted nowrap
            " Purely cosmetic (statusline); harmless to skip if the name is
            " taken because another list window is open.
            silent! execute 'file' fnameescape('[Buffer List]')
            setlocal filetype=bufferlist
            augroup EditableBufferList
                autocmd! * <buffer>
                autocmd TextChanged,InsertLeave <buffer> call s:Apply()
                " For gg and the like. Every redraw reveals them too, which
                " covers opening the list and coming back to it.
                autocmd CursorMoved <buffer> call s:RevealHints()
            augroup END
            nnoremap <buffer> <CR> <Cmd>call editableBufferList#OpenUnderCursor()<CR>
        endif
    endif
    call s:Render(bufnr('%'))
    " Start on '#', the buffer this window was showing. Line 1 if it is gone.
    call cursor(max([1, match(getline(1, '$'), '^\s*\d\+ #') + 1]), 1)
    call s:RevealHints()
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
