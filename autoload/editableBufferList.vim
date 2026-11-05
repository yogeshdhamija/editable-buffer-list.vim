" Location: autoload/editableBufferList.vim
" Maintainer: Yogesh Dhamija <yogeshdhamija@outlook.com>

if(exists("g:autoloaded_editable_buffer_list"))
    finish
endif
let g:autoloaded_editable_buffer_list = 1

" The list is a plain modifiable scratch buffer, so anything that edits text
" works on it: dd, d2j, Vd, :g/foo/d, p. After every change the visible lines
" are diffed against the real buffer list -- a line that disappeared unloads
" its buffer, a line that appeared relists it. Only the leading buffer number
" is ever read back from the text; everything else is redrawn from reality,
" so a mangled line is swept away rather than misread.
"
" Undo is the plugin's own, not Vim's: a history of which buffers each edit
" unlisted and relisted, which u and CTRL-R step back and forth through. See
" s:undo.
"
" The text itself is :ls output, sorted (by name, unless gs picks another
" order) and without the "line N" at the end of each line -- see s:Tidy.

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

" Most recently created first. Buffer numbers only ever go up, so the newest
" buffer has the highest.
function! s:CompareCreated(a, b) abort
    return s:ParseBufnr(a:b) - s:ParseBufnr(a:a)
endfunction

" When each buffer was last used, for the 'used' order: [lastused, leave
" count], filled in by s:Tidy just before it sorts. Vim and Neovim set
" 'lastused' when a buffer is left, so the buffer the list replaced is the
" most recent. It counts whole seconds, though, so buffers left in the same
" second tie on it; the count, which goes up on every BufLeave, puts those in
" the order they were really left. It only starts counting once this file is
" loaded, at the first :BufferList, which is what 'lastused' is there for: it
" covers everything before that.
let s:used = {}
let s:left = {}
let s:leaves = 0

function! s:NoteLeft(buf) abort
    let s:leaves += 1
    let s:left[a:buf] = s:leaves
endfunction

" Most recently used first. Never-used buffers (:badd) all tie at the
" bottom, newest first.
function! s:CompareUsed(a, b) abort
    let l:a = s:ParseBufnr(a:a)
    let l:b = s:ParseBufnr(a:b)
    let l:used_a = get(s:used, l:a, [0, 0])
    let l:used_b = get(s:used, l:b, [0, 0])
    if(l:used_a[0] != l:used_b[0])
        return l:used_b[0] > l:used_a[0] ? 1 : -1
    elseif(l:used_a[1] != l:used_b[1])
        return l:used_b[1] > l:used_a[1] ? 1 : -1
    endif
    return l:b - l:a
endfunction

" The orders gs cycles through, as [setting, description].
let s:sorts = [
    \ ['name',    'name'],
    \ ['used',    'recently used'],
    \ ['created', 'recently created'],
    \ ]

" Index into s:sorts of the order in effect. Read on every redraw, like the
" other settings, so that setting it by hand takes effect at the next one. An
" unknown value is taken as 'name'.
function! s:SortIndex() abort
    let l:sort = get(g:, 'editable_buffer_list_sort', 'name')
    let l:i = 0
    for [l:name, l:description] in s:sorts
        if(l:name ==# l:sort)
            return l:i
        endif
        let l:i += 1
    endfor
    return 0
endfunction

" :ls output as the list shows it: in the order g:editable_buffer_list_sort
" says, with no line numbers. Only the leading buffer number is ever read
" back, so the order is free to be anything.
function! s:Tidy(lines) abort
    call map(a:lines, 's:StripLnum(v:val)')
    let l:sort = s:sorts[s:SortIndex()][0]
    if(l:sort ==# 'used')
        let s:used = {}
        for l:info in getbufinfo()
            let s:used[l:info.bufnr] = [get(l:info, 'lastused', 0), get(s:left, l:info.bufnr, 0)]
        endfor
        return sort(a:lines, function('s:CompareUsed'))
    elseif(l:sort ==# 'created')
        return sort(a:lines, function('s:CompareCreated'))
    endif
    return sort(a:lines, function('s:CompareNames'))
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
    highlight default link bufferListHintCurrent Title
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
" long to read. Last, a rule across the window, so the hints read as a header
" rather than running straight into the first entry.
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
        \ [['gs', 'bufferListHintKey'], [' to sort: ', 'bufferListHint']] + s:SortChoices(),
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
    " Box drawing where the encoding has it. Measured rather than counted as
    " one cell: it is two wide with 'ambiwidth' double.
    let l:rule = &encoding ==# 'utf-8' ? "\u2500" : '-'
    call add(l:hints, [[repeat(l:rule, max([1, a:width / strdisplaywidth(l:rule)])), 'bufferListHint']])
    return l:hints
endfunction

" Every order gs cycles through, as chunks, the one in effect in brackets:
" "[name]/used/created". All of them rather than just the current one, so
" the hint says what gs will do next, and so its width never changes as gs
" moves through them, which would rewrap the hints. The brackets are what
" mark it in Vim, where a hint line has only the one color.
function! s:SortChoices() abort
    let l:current = s:SortIndex()
    let l:chunks = []
    let l:i = 0
    for [l:name, l:description] in s:sorts
        if(l:i > 0)
            call add(l:chunks, ['/', 'bufferListHint'])
        endif
        call add(l:chunks, l:i == l:current
            \ ? ['[' . l:name . ']', 'bufferListHintCurrent']
            \ : [l:name, 'bufferListHint'])
        let l:i += 1
    endfor
    return l:chunks
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

" Vim draws text above a line as part of that line, and 'cursorline' along
" with it: with the cursor on the first entry, every row of the hints would be
" highlighted too, the rule meant to set them apart included. A text property
" cannot take that back, since highlights only ever add up. So in Vim, on that
" one line, the row is highlighted with a match instead, which covers the
" line's own text and nothing above it. The line number is the exception:
" with 'cursorlineopt' at "number", Vim highlights it on the line's own row
" only, so where the option includes the number, that is all it is cut down
" to. A match belongs to the window rather than the buffer, so this also runs
" on every BufEnter and WinEnter, to take it away from a window that has
" moved on to some other buffer.
function! s:CursorRow() abort
    if(has('nvim') || !s:hints_supported)
        return
    endif
    let l:in_list = &filetype ==# 'bufferlist'
    let l:first = l:in_list && line('.') == 1 && get(g:, 'editable_buffer_list_hints', 1)
    if(l:in_list && !l:first)
        call s:HighlightRow()
    elseif(l:first && &l:cursorlineopt =~# '\<\%(number\|both\)\>')
        setlocal cursorlineopt=number
    elseif(l:first)
        setlocal nocursorline
    endif
    let l:id = get(w:, 'editable_buffer_list_cursor_row', 0)
    if(l:first && !l:id)
        let w:editable_buffer_list_cursor_row = matchaddpos('CursorLine', [1])
    elseif(!l:first && l:id)
        silent! call matchdelete(l:id)
        let w:editable_buffer_list_cursor_row = 0
    endif
endfunction

" Which entry the cursor is on in each window showing a:list_buf, as {winid:
" buffer number}. A window whose cursor is on a line with no buffer is left
" out.
function! s:CursorEntries(list_buf) abort
    let l:entries = {}
    if(!exists('*win_execute'))
        return l:entries
    endif
    for l:winid in win_findbuf(a:list_buf)
        let l:nr = s:ParseBufnr(get(getbufline(a:list_buf, line('.', l:winid)), 0, ''))
        if(l:nr)
            let l:entries[l:winid] = l:nr
        endif
    endfor
    return l:entries
endfunction

" Puts each window's cursor back on the entry it was on, wherever that entry
" is now. One that is gone leaves the cursor where it is.
function! s:RestoreCursorEntries(list_buf, entries) abort
    let l:lines = getbufline(a:list_buf, 1, '$')
    for [l:winid, l:nr] in items(a:entries)
        let l:lnum = match(l:lines, '^\s*' . l:nr . '\>') + 1
        if(l:lnum && l:lnum != line('.', str2nr(l:winid)))
            call win_execute(str2nr(l:winid), 'call cursor(' . l:lnum . ', col("."))')
        endif
    endfor
endfunction

" a:skip is a buffer to leave out even though :ls still reports it -- see the
" BufDelete autocmd below -- or 0.
function! s:Render(list_buf, skip) abort
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
    if(a:skip)
        " String concatenation for older Vim, which has no lambdas.
        call filter(l:lines, 's:ParseBufnr(v:val) != ' . a:skip)
    endif
    if(empty(l:lines))
        let l:lines = ['']
    endif
    let l:old_lines = getbufline(a:list_buf, 1, '$')
    if(l:lines !=# l:old_lines)
        " The lines may have moved, so each window's cursor is kept on the
        " entry it was on, rather than the line number.
        let l:cursors = s:CursorEntries(a:list_buf)
        call setbufline(a:list_buf, 1, l:lines)
        if(len(l:old_lines) > len(l:lines))
            call deletebufline(a:list_buf, len(l:lines) + 1, '$')
        endif
        call s:RestoreCursorEntries(a:list_buf, l:cursors)
    endif
    call s:DrawHints(a:list_buf, l:lines, l:winid)
    " The hints may have just been turned on or off.
    if(l:winid == win_getid())
        call s:CursorRow()
    endif
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
    " For the 'used' order.
    autocmd BufLeave * call s:NoteLeft(str2nr(expand('<abuf>')))
    " Trigger background list refresh on all relevant global buffer lifecycle and focus events
    autocmd BufAdd,BufFilePost,BufEnter,BufWritePost * call s:UpdateAll()
    " These two fire *before* the buffer leaves the list, and Vim has no
    " matching "after" event, so :ls here still reports the buffer that is on
    " its way out. Rather than defer the redraw until it is really gone, drop
    " that one buffer from this redraw: <abuf> names it exactly. The event
    " only fires once the delete is actually going through, so a refused
    " :bdelete never reaches this and never hides a line that is staying.
    autocmd BufDelete,BufWipeout * call s:UpdateAll(str2nr(expand('<abuf>')))
    autocmd BufWipeout * call s:Forget(str2nr(expand('<abuf>')))
    " For the '+' flag: editing a buffer in another window fires none of the
    " above. Neovim has an event for 'modified' changing; Vim does not, so it
    " has to look after every change.
    if(exists('##BufModifiedSet'))
        autocmd BufModifiedSet * call s:FollowModified(str2nr(expand('<abuf>')))
    else
        autocmd TextChanged,TextChangedI * call s:FollowModified(bufnr('%'))
    endif
    autocmd ColorScheme * call s:DefineHighlights()
    autocmd BufEnter,WinEnter * call s:CursorRow()
    " The hints are laid out to fit the window, so lay them out again when it
    " changes size.
    autocmd VimResized * call s:UpdateAll()
    if(exists('##WinResized'))
        autocmd WinResized * call s:UpdateAll()
    endif
augroup END

" The undo history, shared by every list: the changes made from lists,
" oldest first, each as {'unlisted': [buffer numbers], 'relisted': [buffer
" numbers]}. u takes the last one off s:undo and does the opposite --
" relists what it unlisted, unlists what it relisted -- and moves it to
" s:redo. CTRL-R does it again, and moves it back.
"
" Vim's own undo is off in the list ('undolevels' -1). It works on text, and
" the text is a poor record of the buffer list: the list redraws itself
" whenever anything changes, and every redraw would be an undo step too.
" Undoing one takes the text back to an older buffer list, which s:Apply
" would then act on as if it were an edit -- deleting the buffers opened
" since, or every buffer, undoing the list's first draw. And undoing a delete
" does not quite put things back: the buffer returns unloaded, so its
" restored line is wrong about that, and the redraw fixing it would be the
" next thing u undid. Kept as buffers rather than text, the history needs
" none of that handled, and nothing done to the text can lose it.
let s:undo = []
let s:redo = []

" Unlists the buffers in a:unlist with the delete command, and relists those
" in a:relist, leaving any that already are. Returns what actually changed --
" a delete can be refused -- in the form the history keeps, plus the errors
" the delete command raised, as 'errors'.
function! s:Change(unlist, relist) abort
    " Looked up every time rather than once at load, so setting it after the
    " plugin has loaded still takes effect.
    let l:delete = get(g:, 'editable_buffer_list_delete_command', 'bdelete')
    let l:done = {'unlisted': [], 'relisted': [], 'errors': []}
    " The lists are redrawn once at the end, rather than after every buffer.
    let g:editable_buffer_list_applying = 1
    try
        for l:b in a:unlist
            if(buflisted(l:b))
                try
                    execute l:delete l:b
                catch
                    call add(l:done.errors, matchstr(v:exception, 'E\d\+.*'))
                endtry
                " A buffer the command wiped cannot be brought back, so it
                " is not recorded.
                if(bufexists(l:b) && !buflisted(l:b))
                    call add(l:done.unlisted, l:b)
                endif
            endif
        endfor
        " :bdelete only unlists a buffer -- it still exists -- which is what
        " lets this bring it back. A configured delete command has to leave
        " buffers existing for the same reason.
        for l:b in a:relist
            if(bufexists(l:b) && !buflisted(l:b))
                call setbufvar(l:b, '&buflisted', 1)
                call add(l:done.relisted, l:b)
            endif
        endfor
    finally
        let g:editable_buffer_list_applying = 0
    endtry
    return l:done
endfunction

" Adds a change made from a list to the history. Like any new change, it
" starts a new future: nothing undone before it can be redone after it.
function! s:Record(change) abort
    if(empty(a:change.unlisted) && empty(a:change.relisted))
        return
    endif
    call add(s:undo, {'unlisted': a:change.unlisted, 'relisted': a:change.relisted})
    let s:redo = []
    " As many as Vim would keep.
    if(len(s:undo) > max([1, &g:undolevels]))
        call remove(s:undo, 0)
    endif
endfunction

" A wiped buffer cannot come back, so it is dropped from the history, and a
" change left with nothing in it goes too: u skips straight past it.
function! s:Forget(buf) abort
    for l:history in [s:undo, s:redo]
        for l:change in l:history
            call filter(l:change.unlisted, 'v:val != ' . a:buf)
            call filter(l:change.relisted, 'v:val != ' . a:buf)
        endfor
        call filter(l:history, '!empty(v:val.unlisted) || !empty(v:val.relisted)')
    endfor
endfunction

function! s:Warn(errors) abort
    if(!empty(a:errors))
        echohl WarningMsg
        echomsg join(a:errors, ' | ')
        echohl None
    endif
endfunction

function! s:Apply() abort
    let l:visible = {}
    for l:line in getline(1, '$')
        let l:nr = s:ParseBufnr(l:line)
        if(l:nr)
            let l:visible[l:nr] = 1
        endif
    endfor
    let l:change = s:Change(filter(s:Listed(), '!has_key(l:visible, v:val)'),
        \ map(keys(l:visible), 'str2nr(v:val)'))
    call s:Record(l:change)
    " Redraw from reality. This converges: the redraw fires one more
    " TextChanged, which then finds text and reality already agreeing. It is
    " also what puts a line back when its buffer refused to unload. Every
    " list, not just this one: they all show the same buffers.
    call s:UpdateAll()
    call s:Warn(l:change.errors)
endfunction

" Moves up to a:count changes from a:from to a:to, undoing them if a:undo is
" set and redoing them otherwise. a:none is what to say when a:from is empty.
function! s:Step(from, to, count, undo, none) abort
    if(empty(a:from))
        echo a:none
        return
    endif
    let l:back = []
    let l:gone = []
    let l:errors = []
    let l:i = 0
    while(l:i < a:count && !empty(a:from))
        let l:change = remove(a:from, -1)
        let l:done = a:undo
            \ ? s:Change(l:change.relisted, l:change.unlisted)
            \ : s:Change(l:change.unlisted, l:change.relisted)
        call extend(l:back, l:done.relisted)
        call extend(l:gone, l:done.unlisted)
        call extend(l:errors, l:done.errors)
        call add(a:to, l:change)
        let l:i += 1
    endwhile
    call s:UpdateAll()

    " Onto the topmost buffer that came back, as Vim's undo puts the cursor
    " on the topmost line it changed.
    let l:lines = getline(1, '$')
    let l:top = 0
    for l:b in l:back
        let l:lnum = match(l:lines, '^\s*' . l:b . '\>') + 1
        if(l:lnum && (!l:top || l:lnum < l:top))
            let l:top = l:lnum
        endif
    endfor
    if(l:top)
        call cursor(l:top, 1)
    endif

    if(!empty(l:errors))
        call s:Warn(l:errors)
        return
    endif
    let l:said = []
    for [l:verb, l:bufs] in [['relisted', l:back], ['deleted', l:gone]]
        if(!empty(l:bufs))
            call add(l:said, l:verb . ' ' . len(l:bufs) . (len(l:bufs) == 1 ? ' buffer' : ' buffers'))
        endif
    endfor
    if(!empty(l:said))
        echo (a:undo ? 'Undo: ' : 'Redo: ') . join(l:said, ', ')
    endif
endfunction

function! editableBufferList#Undo(count) abort
    call s:Step(s:undo, s:redo, a:count, 1, 'Already at oldest change')
endfunction

function! editableBufferList#Redo(count) abort
    call s:Step(s:redo, s:undo, a:count, 0, 'Already at newest change')
endfunction

" 'cursorline' on, and highlighting the row and not just the line number.
" A 'cursorlineopt' of only "number" -- a way of keeping 'cursorline' quiet
" everywhere else -- would leave nothing but the number to show which entry
" the cursor is on. So "line" is added, keeping whatever else the option has.
function! s:HighlightRow() abort
    setlocal cursorline
    if(exists('+cursorlineopt') && &l:cursorlineopt !~# '\<\%(line\|screenline\|both\)\>')
        setlocal cursorlineopt+=line
    endif
endfunction

" How a window showing a list looks: the cursor's row highlighted, to show
" which entry <CR> or dd will act on. Line numbers and the sign column are
" left as the window has them. These are window options, so they are set
" each time a list is shown in a window rather than once for the buffer, and
" with :setlocal, so a window that moves on to another buffer goes back to
" its usual values (see |local-options|).
function! s:WindowOptions() abort
    setlocal nowrap
    call s:HighlightRow()
    " Which takes the row highlight off again on the first entry, in Vim.
    call s:CursorRow()
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
            setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
            " Vim's undo is replaced by the list's own -- see s:undo.
            setlocal undolevels=-1
            " Purely cosmetic (statusline); harmless to skip if the name is
            " taken because another list window is open.
            silent! execute 'file' fnameescape('[Buffer List]')
            setlocal filetype=bufferlist
            augroup EditableBufferList
                autocmd! * <buffer>
                autocmd TextChanged,InsertLeave <buffer> call s:Apply()
                " For gg and the like. Every redraw reveals them too, which
                " covers opening the list and coming back to it.
                autocmd CursorMoved <buffer> call s:RevealHints() | call s:CursorRow()
                " Coming back to the list (CTRL-O), or showing it in another
                " window.
                autocmd BufWinEnter <buffer> call s:WindowOptions()
            augroup END
            nnoremap <buffer> <CR> <Cmd>call editableBufferList#OpenUnderCursor()<CR>
            " oil.nvim's key for the same thing. Plain s, which netrw and
            " bufexplorer use, is an edit here, and gs (go to sleep) is not.
            nnoremap <buffer> gs <Cmd>call editableBufferList#CycleSort()<CR>
            nnoremap <buffer> u <Cmd>call editableBufferList#Undo(v:count1)<CR>
            nnoremap <buffer> <C-R> <Cmd>call editableBufferList#Redo(v:count1)<CR>
        endif
    endif
    call s:WindowOptions()
    call s:Render(bufnr('%'), 0)
    " Start on '#', the buffer this window was showing. Line 1 if it is gone.
    call cursor(max([1, match(getline(1, '$'), '^\s*\d\+ #') + 1]), 1)
    call s:RevealHints()
    call s:CursorRow()
endfunction

" Every list follows, since the setting is global. Each cursor stays on its
" entry -- see s:Render.
function! editableBufferList#CycleSort() abort
    let l:next = s:sorts[(s:SortIndex() + 1) % len(s:sorts)]
    let g:editable_buffer_list_sort = l:next[0]
    call s:UpdateAll()
    echo 'Buffer list sorted by ' . l:next[1]
endfunction

" The full path of the buffer on the cursor's line, as expand('%:p') would
" give it in that buffer -- for a mapping or command that copies it. Empty if
" the line has no buffer, or the buffer has no name.
function! editableBufferList#PathUnderCursor() abort
    let l:b = s:ParseBufnr(getline('.'))
    if(!l:b || !bufexists(l:b) || empty(bufname(l:b)))
        return ''
    endif
    return expand('#' . l:b . ':p')
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
