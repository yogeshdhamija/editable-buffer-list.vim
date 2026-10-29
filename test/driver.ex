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
:call Sync()
:execute "normal! dd"
:call Is(buflisted(g:b), 0, 'b.txt was unloaded')
:call Is(buflisted(bufnr('a.txt')), 1, 'a.txt was left alone')
:call Is(buflisted(bufnr('c.txt')), 1, 'c.txt was left alone')
:call Is(LineOf('b.txt'), 0, 'its line is gone from the list')
:call Ok(bufexists(g:b), 'the buffer still exists, it was only unlisted')

:call Describe('u brings the buffer back')
:call Is(&modifiable, 1, 'the list is still modifiable')
:call Sync()
:execute "normal! u"
:call Is(buflisted(g:b), 1, 'u relisted b.txt')
:call Ok(LineOf('b.txt') > 0, 'and its line is back in the list')
:call Is(buflisted(bufnr('a.txt')), 1, 'a.txt still listed')
:call Is(buflisted(bufnr('c.txt')), 1, 'c.txt still listed')


Anything that removes text works, not just dd.

:call Describe('multi-line deletes')
:call Reset()
:edit a.txt
:edit b.txt
:edit c.txt
:BufferList
:call GotoEntry('a.txt')
:call Sync()
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
:call Sync()
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
:call Sync()
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
:if g:tl | call Sync() | endif
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
:call Sync()
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
:call Sync()
:execute "normal! dd"
:call Is(buflisted(g:b), 0, 'a.txt unloaded')
:call Sync()
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
:call Sync()
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
:call Sync()
:execute "normal! dd"
:call Is(g:deleted, [g:b], 'the command ran once, given the buffer number')
:call Is(buflisted(g:b), 0, 'b.txt was unloaded')
:call Is(winnr('$'), 2, 'the window that showed it is still open')
:call Is(LineOf('b.txt'), 0, 'its line is gone from the list')
:call Is(buflisted(bufnr('a.txt')), 1, 'a.txt was left alone')
:call Sync()
:execute "normal! u"
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
:call Sync()
:execute "normal! dd"
:call Is(g:deleted, [g:a], 'the command was asked to delete a.txt')
:call Is(buflisted(g:a), 1, 'a.txt is still listed')
:call Ok(LineOf('a.txt') > 0, 'so its line came back')
:unlet g:editable_buffer_list_delete_command

:call Finish()
