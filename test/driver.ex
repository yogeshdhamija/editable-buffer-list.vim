# Typed into Vim as keystrokes by run.sh -- see harness.vim for why.
#
# Only lines beginning with ':' are fed to Vim; everything else is a comment.
# Never use a bare :normal, it swallows the rest of the line including the
# bars. :execute "normal! ..." instead.


The list replaces the current window, and does not list itself.

:call Describe('opening the list')
:call Reset()
:edit a.txt
:edit b.txt
:let g:wins = winnr('$')
:BufferList
:call Is(&filetype, 'bufferlist', 'the current window now holds the list')
:call Is(winnr('$'), g:wins, 'no new window was opened')
:call Ok(LineOf('a.txt') > 0, 'a.txt is listed')
:call Ok(LineOf('b.txt') > 0, 'b.txt is listed')
:call Is(LineOf('[Buffer List]'), 0, 'the list does not appear in itself')
:call Ok(getline('.') =~# 'b\.txt', 'the cursor starts on the # entry, b.txt')
:call Ok(getline(LineOf('b.txt')) =~# '\d\+ #', 'and b.txt is really marked #')


The lines are sorted by name, ignoring case, rather than by buffer number,
and the "line N" :ls ends each line with is left off. Buffer numbers here run
c, a, B, so the order on screen and the order of the numbers disagree.

:call Describe('the list is sorted by name, without line numbers')
:call Reset()
:edit c.txt
:edit a.txt
:badd B.md
:BufferList
:call Is(Names(), ['a.txt', 'B.md', 'c.txt'], 'sorted by name, ignoring case')
:call Is(filter(getline(1, '$'), 'v:val =~# "line"'), [], 'no line ends in a line number')
:call Ok(getline('.') =~# 'a\.txt', 'the cursor still starts on the # entry')
:badd aa.txt
:call Is(Names(), ['a.txt', 'aa.txt', 'B.md', 'c.txt'], 'a buffer added later is drawn in its place')
:call GotoEntry('B.md')
:execute "normal! dd"
:call Is(buflisted(bufnr('B.md')), 0, 'dd unloaded B.md, the buffer on that line')
:call Is(Names(), ['a.txt', 'aa.txt', 'c.txt'], 'and nothing else')
:execute "normal u"
:call Is(buflisted(bufnr('B.md')), 1, 'u relisted it')
:call Is(Names(), ['a.txt', 'aa.txt', 'B.md', 'c.txt'], 'back in its place')


gs cycles the order: by name, most recently used first, most recently
created first, and back. Created c, a, b, then used c again, the three
orders all disagree. Every list follows, and each cursor stays on its entry.

:call Describe('gs cycles the sort order')
:call Reset()
:edit c.txt
:edit a.txt
:edit b.txt
:edit c.txt
:BufferList
:call Is(Names(), ['a.txt', 'b.txt', 'c.txt'], 'by name to begin with')
:if g:hints_supported | call Ok(join(Hints()) =~# 'gs to sort: \[name\]/used/created', 'the hints say so') | endif
:call GotoEntry('b.txt')
:execute "normal gs"
:call Is(get(g:, 'editable_buffer_list_sort', ''), 'used', 'gs switched to most recently used')
:call Is(Names(), ['c.txt', 'b.txt', 'a.txt'], 'c.txt, the buffer the list replaced, first')
:call Ok(getline('.') =~# 'b\.txt', 'the cursor stayed on b.txt')
:if g:hints_supported | call Ok(join(Hints()) =~# 'gs to sort: name/\[used\]/created', 'the hints follow') | endif
:if has('nvim-0.6') | call Is([HintGroup('[used]'), HintGroup('name')], ['bufferListHintCurrent', 'bufferListHint'], 'the order in effect has a color of its own') | endif
:execute "normal gs"
:call Is(g:editable_buffer_list_sort, 'created', 'then to most recently created')
:call Is(Names(), ['b.txt', 'a.txt', 'c.txt'], 'b.txt, the newest buffer, first')
:call Ok(getline('.') =~# 'b\.txt', 'the cursor still on b.txt')
:execute "normal gs"
:call Is(g:editable_buffer_list_sort, 'name', 'and back to by name')
:call Is(Names(), ['a.txt', 'b.txt', 'c.txt'], 'in name order again')
:unlet g:editable_buffer_list_sort

:call Describe('the sort order can be set ahead of time')
:call Reset()
:let g:editable_buffer_list_sort = 'used'
:edit a.txt
:badd z.txt
:edit c.txt
:edit b.txt
:BufferList
:call Is(Names(), ['b.txt', 'c.txt', 'a.txt', 'z.txt'], 'most recently used first, never-entered z.txt last')
:call Ok(getline('.') =~# 'b\.txt', 'the cursor starts on #, at the top')
:let g:editable_buffer_list_sort = 'bogus'
:BufferList
:call Is(Names(), ['a.txt', 'b.txt', 'c.txt', 'z.txt'], 'an unknown order means by name')
:unlet g:editable_buffer_list_sort

With most recently used first, a list on screen reorders as buffers are
used in other windows, and its cursor stays on its entry.

:call Describe('the most recently used order follows other windows')
:call Reset()
:let g:editable_buffer_list_sort = 'used'
:edit a.txt
:edit b.txt
:edit c.txt
:BufferList
:let g:list = bufnr('%')
:let g:listwin = win_getid()
:call GotoEntry('b.txt')
:split
:edit a.txt
:edit c.txt
:call Is(map(getbufline(g:list, 1, '$'), 'matchstr(v:val, ''"\zs.*\ze"'')'), ['a.txt', 'c.txt', 'b.txt'], 'a.txt, just left, is first')
:call Ok(getbufline(g:list, line('.', g:listwin))[0] =~# 'b\.txt', 'the list cursor stayed on b.txt')
:only
:unlet g:editable_buffer_list_sort


<CR> opens the entry under the cursor, in the same window.

:call Describe('<CR> opens the entry under the cursor')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:call GotoEntry('a.txt')
:execute "normal \<CR>"
:call Is(bufname('%'), 'a.txt', '<CR> switched this window to a.txt')
:call Is(winnr('$'), 1, 'still one window')
:call Is(bufname('#'), 'b.txt', 'keepalt kept # on the pre-list buffer')


editableBufferList#PathUnderCursor() is for a "copy path" command: the
path of the entry under the cursor, as expand('%:p') would give it there.

:call Describe('the path of the entry under the cursor')
:call Reset()
:enew
:call setline(1, 'unsaved, so it stays')
:badd a.txt
:badd foo://bar/baz
:BufferList
:call GotoEntry('a.txt')
:call Is(editableBufferList#PathUnderCursor(), fnamemodify('a.txt', ':p'), 'a file gives its full path')
:call GotoEntry('foo://bar/baz')
:call Is(editableBufferList#PathUnderCursor(), 'foo://bar/baz', 'a scheme:// name is given as it is')
:call GotoEntry('[No Name]')
:call Is(editableBufferList#PathUnderCursor(), '', 'a buffer with no name gives nothing')


Navigating away and coming back with CTRL-O. This is why the list buffer is
hidden rather than wiped: wiping it would drop its jumplist entries.

:call Describe('CTRL-O returns to the list')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:let g:list = bufnr('%')
:edit c.txt
:execute "normal! \<C-O>"
:call Is(bufnr('%'), g:list, 'CTRL-O landed back on the list buffer')
:call Is(&filetype, 'bufferlist', 'it is still a working list')
:call Ok(LineOf('c.txt') > 0, 'and it was redrawn, so c.txt now shows')
:call Is(buflisted(g:list), 0, 'the jump did not leave the list buflisted')


Leaving the list without picking anything gets you back where you were.

:call Describe('leaving the list without picking anything')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:execute "normal! \<C-^>"
:call Is(bufname('%'), 'b.txt', 'CTRL-^ returns to the pre-list buffer')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:execute "normal! \<C-O>"
:call Is(bufname('%'), 'b.txt', 'CTRL-O returns to the pre-list buffer')


Deleting a line unloads that buffer and only that buffer; u brings it back.

:call Describe('dd unloads the buffer on that line')
:call Reset()
:edit a.txt
:edit b.txt
:edit c.txt
:BufferList
:let g:b = bufnr('b.txt')
:call GotoEntry('b.txt')
:execute "normal! dd"
:call Is(buflisted(g:b), 0, 'b.txt was unloaded')
:call Is(buflisted(bufnr('a.txt')), 1, 'a.txt was left alone')
:call Is(buflisted(bufnr('c.txt')), 1, 'c.txt was left alone')
:call Is(LineOf('b.txt'), 0, 'its line is gone from the list')
:call Ok(bufexists(g:b), 'the buffer still exists, it was only unlisted')

:call Describe('u brings the buffer back')
:call Is(&modifiable, 1, 'the list is still modifiable')
:execute "normal u"
:call Is(buflisted(g:b), 1, 'u relisted b.txt')
:call Ok(LineOf('b.txt') > 0, 'and its line is back in the list')
:call Ok(getline('.') =~# 'b\.txt', 'with the cursor on it')
:call Is(buflisted(bufnr('a.txt')), 1, 'a.txt still listed')
:call Is(buflisted(bufnr('c.txt')), 1, 'c.txt still listed')
:execute "normal \<C-R>"
:call Is(buflisted(g:b), 0, 'CTRL-R unloaded it again')
:call Is(LineOf('b.txt'), 0, 'and took its line away')


u and CTRL-R step through a history of which buffers each edit unlisted and
relisted, which the plugin keeps itself: Vim's own undo is off in the list.
So they go back and forth as far as there is history, and the list is
redrawn from reality each time.

:call Describe('dd four times, then u four times')
:call Reset()
:edit a.txt
:edit b.txt
:edit c.txt
:edit d.txt
:edit e.txt
:BufferList
:call Is(&l:undolevels, -1, "Vim's own undo is off in the list")
:execute "normal! ggdd"
:execute "normal! dd"
:execute "normal! dd"
:execute "normal! dd"
:call Is(Names(), ['e.txt'], 'four dd deleted a.txt to d.txt')
:execute "normal u"
:execute "normal u"
:call Is(Names(), ['c.txt', 'd.txt', 'e.txt'], 'two u brought back d.txt and c.txt')
:execute "normal u"
:execute "normal u"
:call Is(Names(), ['a.txt', 'b.txt', 'c.txt', 'd.txt', 'e.txt'], 'four brought back all four')
:call Is(len(getbufinfo({'buflisted': 1})), 5, 'all five really are listed')
:call Ok(getline(LineOf('a.txt')) =~# '^\s*\d\+\s\+"', 'and shown as they are now, not loaded')
:execute "normal u"
:call Is(len(getbufinfo({'buflisted': 1})), 5, 'a fifth u has nothing left to undo')
:execute "normal 2\<C-R>"
:call Is(Names(), ['c.txt', 'd.txt', 'e.txt'], '2 CTRL-R deleted a.txt and b.txt again')
:execute "normal 2u"
:call Is(Names(), ['a.txt', 'b.txt', 'c.txt', 'd.txt', 'e.txt'], 'and 2u brought them back')
:call GotoEntry('e.txt')
:execute "normal! dd"
:execute "normal \<C-R>"
:call Is(Names(), ['a.txt', 'b.txt', 'c.txt', 'd.txt'], 'a new edit leaves nothing to redo')

The history is of buffers, not of the list's text, so the list redrawing
itself -- for gs, for a buffer opened elsewhere, for being opened again --
leaves it alone. And u undoes only what was done from a list.

:call Describe('the history survives the list redrawing itself')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:execute "normal u"
:call Is(Names(), ['a.txt', 'b.txt'], 'u with nothing to undo changes nothing')
:call GotoEntry('a.txt')
:execute "normal! dd"
:badd c.txt
:execute "normal gs"
:edit c.txt
:BufferList
:call Is(Names(), ['c.txt', 'b.txt'], 'c.txt opened, the list re-sorted and reopened')
:execute "normal u"
:call Is(buflisted(bufnr('a.txt')), 1, 'u still brings a.txt back')
:call Is(buflisted(bufnr('c.txt')), 1, 'and leaves c.txt, opened elsewhere, alone')
:call Ok(getline('.') =~# 'a\.txt', 'with the cursor on a.txt')
:unlet g:editable_buffer_list_sort

Putting a deleted line back relists its buffer. That is an edit like any
other, so u undoes it.

:call Describe('p relists, and u undoes that too')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:call GotoEntry('a.txt')
:execute "normal! dd"
:call Is(buflisted(bufnr('a.txt')), 0, 'dd unloaded a.txt')
:execute "normal! p"
:call Is(buflisted(bufnr('a.txt')), 1, 'p put its line back, relisting it')
:execute "normal u"
:call Is(buflisted(bufnr('a.txt')), 0, 'u undid the p')
:execute "normal u"
:call Is(buflisted(bufnr('a.txt')), 1, 'and u again, the dd')

:call Describe('every list shares the one history')
:call Reset()
:edit a.txt
:BufferList
:let g:l1 = win_getid()
:let g:list = bufnr('%')
:vsplit
:edit b.txt
:BufferList
:call GotoEntry('a.txt')
:execute "normal! dd"
:call Ok(!HasEntry(g:list, 'a.txt'), 'the other list dropped a.txt too, at once')
:call win_gotoid(g:l1)
:execute "normal u"
:call Is(buflisted(bufnr('a.txt')), 1, 'and u there brought it back')
:only

A wiped buffer cannot come back, so it drops out of the history.

:call Describe('wiped buffers drop out of the history')
:call Reset()
:edit a.txt
:edit b.txt
:edit c.txt
:BufferList
:let g:b = bufnr('b.txt')
:call GotoEntry('a.txt')
:execute "normal! dd"
:call GotoEntry('b.txt')
:execute "normal! dd"
:execute 'bwipeout' g:b
:execute "normal u"
:call Is(buflisted(bufnr('a.txt')), 1, 'one u skipped the wiped b.txt and brought back a.txt')
:call Is(Names(), ['a.txt', 'c.txt'], 'and nothing else')


Anything that removes text works, not just dd.

:call Describe('multi-line deletes')
:call Reset()
:edit a.txt
:edit b.txt
:edit c.txt
:BufferList
:call GotoEntry('a.txt')
:execute "normal! 2dd"
:call Is(buflisted(bufnr('a.txt')), 0, '2dd unloaded a.txt')
:call Is(buflisted(bufnr('b.txt')), 0, '2dd unloaded b.txt')
:call Is(buflisted(bufnr('c.txt')), 1, 'c.txt survived')

:call Describe(':g//d deletes')
:call Reset()
:edit a.txt
:edit b.txt
:edit c.txt
:BufferList
:g/b\.txt/d
:call Is(buflisted(bufnr('b.txt')), 0, ':g/b.txt/d unloaded b.txt')
:call Is(buflisted(bufnr('a.txt')), 1, 'a.txt untouched')
:call Is(buflisted(bufnr('c.txt')), 1, 'c.txt untouched')


A buffer that refuses to unload keeps its line.

:call Describe('dd will not discard a modified buffer')
:call Reset()
:edit a.txt
:edit b.txt
:call setline(1, 'unsaved change')
:BufferList
:let g:b = bufnr('b.txt')
:call Is(getbufvar(g:b, '&modified'), 1, 'b.txt really is modified')
:call GotoEntry('b.txt')
:execute "normal! dd"
:call Is(buflisted(g:b), 1, 'modified b.txt is still listed')
:call Ok(LineOf('b.txt') > 0, 'its line came back in the list')
:call Is(getbufvar(g:b, '&modified'), 1, 'and its changes are intact')

:call Describe('dd will not kill a terminal with a running job')
:call Reset()
:edit a.txt
:call StartTerm()
:call Ok(!g:term_supported || g:term, 'started a terminal to try to delete')
:if !g:term | call Skip('this build cannot open a terminal, skipping the rest') | endif
:if g:term | call Is(buflisted(g:term), 1, 'the terminal buffer is listed') | endif
:if g:term | execute 'BufferList' | endif

Everything below is gated on having actually found the terminal's line, so a
failed lookup cannot leave the dd to delete some unrelated buffer instead.

:let g:tl = g:term ? LineStarting(bufname(g:term)) : 0
:if g:term | call Ok(g:tl > 0, 'the list has an entry for the terminal') | endif
:if g:tl | call cursor(g:tl, 1) | endif
:if g:tl | execute "normal! dd" | endif
:if g:tl | call Is(buflisted(g:term), 1, 'the terminal is still listed') | endif
:if g:tl | call Ok(LineStarting(bufname(g:term)) > 0, 'its line came back') | endif
:call StopTerm()


A list redraws when some *other* window changes the buffer list.

:call Describe('a list follows changes made in another window')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:let g:list = bufnr('%')
:split
:edit c.txt
:call Ok(HasEntry(g:list, 'c.txt'), 'the list picked up c.txt opened elsewhere')
:call Ok(HasEntry(g:list, 'a.txt'), 'a.txt is still there')
:bdelete a.txt
:call Ok(!HasEntry(g:list, 'a.txt'), 'and dropped a.txt deleted elsewhere')
:call Ok(HasEntry(g:list, 'b.txt'), 'without dropping anything else')
:only


Only the leading buffer number is ever read back.

:call Describe('mangled text is redrawn, not misread')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:let g:n = line('$')
:call GotoEntry('a.txt')
:execute "normal! A garbage garbage\<Esc>"
:call Is(line('$'), g:n, 'the list still has the same number of lines')
:call Is(buflisted(bufnr('a.txt')), 1, 'a.txt was not touched')
:call Ok(getline(LineOf('a.txt')) !~# 'garbage', 'the mangled line was redrawn')

:call Describe('a bare buffer number relists that buffer')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:let g:b = bufnr('a.txt')
:call GotoEntry('a.txt')
:execute "normal! dd"
:call Is(buflisted(g:b), 0, 'a.txt unloaded')
:execute "normal! ggO" . g:b . "\<Esc>"
:call Is(buflisted(g:b), 1, 'writing its number on a line relisted it')


Housekeeping: no nesting, no leaking, one list per window.

:call Describe(':BufferList from inside a list redraws in place')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:let g:list = bufnr('%')
:BufferList
:call Is(bufnr('%'), g:list, 'still the same list buffer')
:call Is(len(ListBuffers()), 1, 'no second list was created')
:call Is(winnr('$'), 1, 'no second window was created')

:call Describe('abandoned lists are reused, not accumulated')
:call Reset()
:edit a.txt
:BufferList
:edit b.txt
:BufferList
:edit c.txt
:BufferList
:edit a.txt
:call Is(len(ListBuffers()), 1, 'one list buffer after three :BufferList')

:call Describe('each window keeps its own list')
:call Reset()
:edit a.txt
:BufferList
:let g:l1 = bufnr('%')
:vsplit
:edit b.txt
:BufferList
:let g:l2 = bufnr('%')
:call Ok(g:l1 != g:l2, 'the second window did not steal the first window list')
:call Is(len(ListBuffers()), 2, 'two lists for two windows')
:call Ok(getbufline(g:l2, LineOf('b.txt'))[0] =~# '\d\+ #', 'each list has its own #')
:only


The list buffer stays out of the way.

:call Describe('list buffer options')
:call Reset()
:edit a.txt
:BufferList
:let g:list = bufnr('%')
:call Is(buflisted(g:list), 0, 'nobuflisted, so it stays out of :ls and :bnext')
:call Is(getbufvar(g:list, '&buftype'), 'nofile', 'buftype=nofile, it never needs saving')
:call Is(getbufvar(g:list, '&bufhidden'), 'hide', 'bufhidden=hide, so CTRL-O can return to it')
:call Is(getbufvar(g:list, '&modified'), 0, 'not modified, so :bdelete needs no bang')
:call Is(getbufvar(g:list, '&swapfile'), 0, 'noswapfile')

The list highlights the cursor's row, and keeps the window's line numbers
and sign column. Those are window options, so it is the window showing the
list that gets them -- and only while it shows the list. UsualOpts() has
'cursorlineopt' highlight only the number, which on its own would leave the
row looking unselected.

The cursor is kept off the first entry here: Vim highlights that one
differently, tested below.

:call Describe('the gutter kept, and a highlighted row, in the list only')
:call Reset()
:call UsualOpts()
:edit a.txt
:edit b.txt
:BufferList
:call Is(line('.'), 2, 'the cursor starts on b.txt, line 2')
:call Is(WinOpts(), g:list_opts, 'the list window keeps its gutter, and highlights the row')
:if g:hints_supported | call Is([Textoff() > 0, strdisplaywidth(get(Hints(), -1, ''))], [1, winwidth(0) - Textoff()], 'the hints are laid out beside the gutter') | endif
:edit c.txt
:call Is(WinOpts(), g:usual_opts, 'a buffer new to the window gets the usual ones')
:buffer a.txt
:call Is(WinOpts(), g:usual_opts, 'a buffer the window showed before the list gets them back too')
:BufferList
:call GotoEntry('b.txt')
:execute "normal \<CR>"
:call Is(WinOpts(), g:usual_opts, 'and so does one opened from the list with <CR>')
:BufferList
:split
:call Is(WinOpts(), g:list_opts, 'splitting the list window keeps the row highlighted in the copy')
:edit c.txt
:call Is(WinOpts(), g:usual_opts, 'until that window moves on to another buffer')
:only

Something else turning the row highlight off in the list -- a :set
nocursorline typed there, say -- is undone the next time the list is shown.
A gutter changed there stays changed, and the hints are laid out for it.

:call Describe('coming back to a list resets its row highlight')
:BufferList
:let g:list = bufnr('%')
:setlocal nocursorline nonumber norelativenumber
:edit b.txt
:execute 'buffer' g:list
:call Is(&l:cursorline, 1, 'the row is highlighted again')
:if g:hints_supported | call Is(strdisplaywidth(get(Hints(), -1, '')), winwidth(0) - Textoff(), 'and the hints are laid out for the gutter it has') | endif
:call DefaultOpts()

Vim draws the hints as part of line 1, and 'cursorline' with them: on the
first entry it would highlight every hint row too. So there, the row is
highlighted with a match on the line's own text instead. The line number
Vim highlights on the line's own row only, so 'cursorline' stays on for
that, cut down to the number -- unless 'cursorlineopt' left the number out
to begin with. Its default, "both", has it.

:call Describe('in Vim, the first entry is highlighted without the hints')
:call Reset()
:let g:vim_hints = g:hints_supported && !has('nvim')
:if !g:vim_hints | call Skip('only Vim draws the hints as part of line 1') | endif
:edit b.txt
:edit a.txt
:BufferList
:let g:list = bufnr('%')
:call Is(line('.'), 1, 'the cursor starts on a.txt, line 1')
:if g:vim_hints | call Is([&l:cursorline, &l:cursorlineopt], [1, 'number'], 'cursorline highlights only the number there') | endif
:if g:vim_hints | call Is(CursorRowMatches(), [[1]], 'and a match highlights line 1 instead') | endif
:execute "normal! j"
:if g:vim_hints | call Is([&l:cursorline, &l:cursorlineopt], [1, 'number,line'], 'one line down, the whole row is highlighted again') | endif
:if g:vim_hints | call Is(CursorRowMatches(), [], 'and the match is gone') | endif
:execute "normal! k"
:if g:vim_hints | call Is(CursorRowMatches(), [[1]], 'back up, the match is back') | endif
:edit c.txt
:call Is(CursorRowMatches(), [], 'leaving the list on line 1 takes the match with it')
:execute 'buffer' g:list
:if g:vim_hints | call Is([&l:cursorlineopt, CursorRowMatches()], ['number', [[1]]], 'and coming back puts it back') | endif
:split
:if g:vim_hints | call Is([&l:cursorlineopt, CursorRowMatches()], ['number', [[1]]], 'a split of the list gets one of its own') | endif
:only
:setlocal cursorlineopt=line
:execute "normal! G"
:execute "normal! gg"
:if g:vim_hints | call Is([&l:cursorline, CursorRowMatches()], [0, [[1]]], 'with the number left out of cursorlineopt, cursorline is off there altogether') | endif
:let g:editable_buffer_list_hints = 0
:BufferList
:call Is([&l:cursorline, CursorRowMatches()], [1, []], 'with no hints, plain cursorline is used')
:unlet g:editable_buffer_list_hints

:call Describe('the list works with nohidden')
:call Reset()
:set nohidden
:edit a.txt
:BufferList
:let g:list = bufnr('%')
:edit b.txt
:call Is(bufexists(g:list), 1, 'the list survived being abandoned under nohidden')
:execute "normal! \<C-O>"
:call Is(bufnr('%'), g:list, 'CTRL-O still returns to it')
:set hidden


The delete command can be swapped out. The default, :bdelete, closes any
other window showing the buffer, which is the reason to swap it.

:call Describe('the default :bdelete closes other windows showing the buffer')
:call Reset()
:edit a.txt
:edit b.txt
:split
:BufferList
:call Is(winnr('$'), 2, 'the list in one window, b.txt in the other')
:call GotoEntry('b.txt')
:execute "normal! dd"
:call Is(buflisted(bufnr('b.txt')), 0, 'b.txt was unloaded')
:call Is(winnr('$'), 1, 'and the window showing it was closed')
:only

:call Describe('g:editable_buffer_list_delete_command replaces :bdelete')
:call Reset()
:let g:editable_buffer_list_delete_command = 'KeepWindowsDelete'
:let g:deleted = []
:edit a.txt
:edit b.txt
:split
:BufferList
:let g:b = bufnr('b.txt')
:call GotoEntry('b.txt')
:execute "normal! dd"
:call Is(g:deleted, [g:b], 'the command ran once, given the buffer number')
:call Is(buflisted(g:b), 0, 'b.txt was unloaded')
:call Is(winnr('$'), 2, 'the window that showed it is still open')
:call Is(LineOf('b.txt'), 0, 'its line is gone from the list')
:call Is(buflisted(bufnr('a.txt')), 1, 'a.txt was left alone')
:execute "normal u"
:call Is(buflisted(g:b), 1, 'u still relists it')
:call Ok(LineOf('b.txt') > 0, 'and its line is back')
:only

:call Describe('a delete command that declines without an error')
:call Reset()
:let g:editable_buffer_list_delete_command = 'IgnoreDelete'
:let g:deleted = []
:edit a.txt
:edit b.txt
:BufferList
:let g:a = bufnr('a.txt')
:call GotoEntry('a.txt')
:execute "normal! dd"
:call Is(g:deleted, [g:a], 'the command was asked to delete a.txt')
:call Is(buflisted(g:a), 1, 'a.txt is still listed')
:call Ok(LineOf('a.txt') > 0, 'so its line came back')
:unlet g:editable_buffer_list_delete_command


The hints above the list: what the keys do and what the flags mean. They are
virtual text, not lines of the buffer. Gated like the terminal tests, since
older builds cannot draw them.

:call Describe('hints explain the keys and the flags in the list')
:call Reset()
:edit a.txt
:call setline(1, 'unsaved change')
:badd c.txt
:edit b.txt
:BufferList
:if !g:hints_supported | call Skip('this build cannot draw virtual text above a line, skipping hints') | endif
:let g:h = join(Hints(), "\n")
:if g:hints_supported | call Ok(g:h =~# 'Updates Live', 'it says edits apply without :w') | endif
:if g:hints_supported | call Ok(g:h =~# '<CR> to open', 'the keys are explained') | endif
:if g:hints_supported | call Ok(g:h =~# 'delete line to :bdelete', 'naming the delete command') | endif
:if g:hints_supported | call Ok(g:h =~# '# = alternate', 'b.txt is #, so # is explained') | endif
:if g:hints_supported | call Ok(g:h =~# 'h = hidden', 'a.txt is h, so h is explained') | endif
:if g:hints_supported | call Ok(g:h =~# '+ = modified', 'a.txt is +, so + is explained') | endif
:if g:hints_supported | call Ok(g:h =~# 'no a or h = unloaded', 'c.txt is not loaded, so that is explained') | endif
:if g:hints_supported | call Ok(g:h !~# 'in a window', 'nothing is a, so a is left out') | endif
:if g:hints_supported | call Is(line('$'), 3, 'the hints are not lines of the buffer') | endif
:if g:hints_supported | call Is(LineOf('a.txt'), 1, 'so line 1 is still the first entry') | endif
:let g:rule = get(Hints(), -1, '')
:if g:hints_supported | call Ok(g:rule =~# '^\%(\%u2500\|-\)\+$', 'the last hint line is a rule, setting them off from the list') | endif
:if g:hints_supported | call Is(strdisplaywidth(g:rule), winwidth(0), 'running the width of the window') | endif

The legend is redrawn along with the list, so a flag turning up elsewhere
gets explained. '+' needs watching for: editing a buffer in another window
fires none of the events that redraw the list otherwise.

:call Describe('a buffer modified in another window shows up as +')
:call Reset()
:edit a.txt
:BufferList
:let g:list = bufnr('%')
:split
:edit b.txt
:let g:clean = '\d\+  a   "b.txt"'
:let g:dirty = '\d\+  a + "b.txt"'
:call Ok(match(getbufline(g:list, 1, '$'), g:clean) >= 0, 'b.txt starts out unmodified, in a window')
:call Sync()
:call setline(1, 'unsaved change')
:call Ok(match(getbufline(g:list, 1, '$'), g:dirty) >= 0, 'the list shows it modified')
:wincmd p
:if g:hints_supported | call Ok(join(Hints()) =~# '+ = modified', 'and the legend explains +') | endif
:wincmd p
:execute "normal u"
:call Ok(match(getbufline(g:list, 1, '$'), g:clean) >= 0, 'undoing back to unmodified clears it')
:call Sync()
:call setline(1, 'unsaved change')
:write
:call Ok(match(getbufline(g:list, 1, '$'), g:clean) >= 0, 'so does writing')
:call setline(1, 'another change')
:call Ok(match(getbufline(g:list, 1, '$'), g:dirty) >= 0, 'and changing it again after the write shows it again')
:only!

The list's lines are what gets redrawn after every change, so the hints
must not end up duplicated or left behind on some other line. In Vim, a
property belongs to its line: dd takes it along, and u brings it back.

:call Describe('the hints stay one set, above line 1, through dd and u')
:call Reset()
:edit a.txt
:edit b.txt
:BufferList
:execute "normal! ggdd"
:call Is(buflisted(bufnr('a.txt')), 0, 'dd on line 1 unloaded a.txt')
:if g:hints_supported | call Is(len(filter(HintLines(), 'v:val[1] =~# "<CR> to open"')), 1, 'one set of hints after dd') | endif
:if g:hints_supported | call Is(filter(HintLines(), 'v:val[0] != 1'), [], 'all of them above the new line 1') | endif
:execute "normal u"
:call Is(buflisted(bufnr('a.txt')), 1, 'u relisted a.txt')
:if g:hints_supported | call Is(len(filter(HintLines(), 'v:val[1] =~# "<CR> to open"')), 1, 'still one set after u') | endif
:if g:hints_supported | call Is(filter(HintLines(), 'v:val[0] != 1'), [], 'still all above line 1') | endif
:call Is(&modified, 0, 'drawing them does not leave the list modified')

:call Describe('the hints name a configured delete command')
:call Reset()
:let g:editable_buffer_list_delete_command = 'KeepWindowsDelete'
:edit a.txt
:BufferList
:if g:hints_supported | call Ok(join(Hints()) =~# 'delete line to :KeepWindowsDelete', 'the configured command is shown') | endif
:unlet g:editable_buffer_list_delete_command

:call Describe('g:editable_buffer_list_hints = 0 turns them off')
:call Reset()
:edit a.txt
:BufferList
:let g:editable_buffer_list_hints = 0
:BufferList
:call Is(HintLines(), [], 'no hints once turned off')
:call Ok(LineOf('a.txt') > 0, 'and the list itself is unaffected')
:unlet g:editable_buffer_list_hints
:BufferList
:if g:hints_supported | call Ok(!empty(Hints()), 'and they come back when it is unset') | endif

Neither editor wraps a virtual line, so the hints are laid out to fit the
window, and laid out again when it is resized.

:call Describe('the hints wrap to fit the window')
:call Reset()
:edit a.txt
:call setline(1, 'unsaved change')
:badd c.txt
:edit b.txt
:vsplit
:vertical resize 32
:BufferList
:let g:narrow = Hints()
:if g:hints_supported | call Ok(len(g:narrow) > 2, 'a narrow window gets more than two lines') | endif
:if g:hints_supported | call Is(filter(copy(g:narrow), 'strdisplaywidth(v:val) > winwidth(0)'), [], 'none wider than the window') | endif
:only
:let g:skip_resize = !g:hints_supported || !exists('##WinResized')
:if !g:skip_resize | call Ok(len(Hints()) < len(g:narrow), 'widening the window took fewer lines') | endif
:if g:skip_resize | call Skip('no WinResized in this build') | endif

Neovim draws lines above line 1 as filler, and only shows them once the
window is scrolled up into them, which the plugin has to do itself.

:call Describe('Neovim scrolls the hints into view')
:call Reset()
:let g:nvim = has('nvim')
:if !g:nvim | call Skip('Vim draws them as part of line 1') | endif
:edit a.txt
:edit b.txt
:BufferList
:if g:nvim | call Is(winsaveview().topfill, len(Hints()), 'opening the list shows them') | endif
:edit c.txt
:execute "normal! \<C-O>"
:if g:nvim | call Is(winsaveview().topfill, len(Hints()), 'so does coming back with CTRL-O') | endif
:for g:i in range(&lines * 2) | execute 'badd' 'extra' . g:i | endfor
:BufferList
:execute "normal! G"
:call Ok(line('w0') > 1, 'G scrolled the long list off its top')
:execute "normal! gg"
:if g:nvim | call Is(winsaveview().topfill, len(Hints()), 'and gg shows them again') | endif


Names in the form scheme://... -- terminals, and buffers other plugins
make -- are highlighted, so they stand out from files. Last, because it
turns syntax highlighting on.

:call Describe('scheme:// names are highlighted')
:call Reset()
:syntax enable
:badd foo://bar/baz
:badd a.txt
:BufferList
:let g:url = LineOf('foo://bar/baz')
:let g:col = stridx(getline(g:url), '"foo') + 2
:call Is(synIDattr(synID(g:url, g:col, 1), 'name'), 'bufferListUrlScheme', 'the scheme has its own group')
:call Is(synIDattr(synID(g:url, g:col + 6, 1), 'name'), 'bufferListUrl', 'and the rest of the name is highlighted')
:call Is(synIDattr(synID(g:url, 3, 1), 'name'), 'bufferListNumber', 'the number and flags still are too')
:let g:file = LineOf('a.txt')
:call Is(synIDattr(synID(g:file, stridx(getline(g:file), '"a') + 2, 1), 'name'), '', 'a file name is left alone')
:syntax off

:call Finish()
