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
:if g:hints_supported | call Ok(g:h =~# '<CR> = open', 'the keys are explained') | endif
:if g:hints_supported | call Ok(g:h =~# 'delete line = :bdelete', 'naming the delete command') | endif
:if g:hints_supported | call Ok(g:h =~# '# alternate', 'b.txt is #, so # is explained') | endif
:if g:hints_supported | call Ok(g:h =~# 'h hidden', 'a.txt is h, so h is explained') | endif
:if g:hints_supported | call Ok(g:h =~# '+ modified', 'a.txt is +, so + is explained') | endif
:if g:hints_supported | call Ok(g:h =~# 'no a/h: not loaded', 'c.txt is not loaded, so that is explained') | endif
:if g:hints_supported | call Ok(g:h !~# 'in a window', 'nothing is a, so a is left out') | endif
:if g:hints_supported | call Ok(g:h =~# ':h :ls', 'and :ls help is pointed to') | endif
:if g:hints_supported | call Is(line('$'), 3, 'the hints are not lines of the buffer') | endif
:if g:hints_supported | call Is(LineOf('a.txt'), 1, 'so line 1 is still the first entry') | endif

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
:if g:hints_supported | call Ok(join(Hints()) =~# '+ modified', 'and the legend explains +') | endif
:wincmd p
:execute "normal! u"
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
:call Sync()
:execute "normal! ggdd"
:call Is(buflisted(bufnr('a.txt')), 0, 'dd on line 1 unloaded a.txt')
:if g:hints_supported | call Is(len(filter(HintLines(), 'v:val[1] =~# "<CR> open"')), 1, 'one set of hints after dd') | endif
:if g:hints_supported | call Is(filter(HintLines(), 'v:val[0] != 1'), [], 'all of them above the new line 1') | endif
:call Sync()
:execute "normal! u"
:call Is(buflisted(bufnr('a.txt')), 1, 'u relisted a.txt')
:if g:hints_supported | call Is(len(filter(HintLines(), 'v:val[1] =~# "<CR> open"')), 1, 'still one set after u') | endif
:if g:hints_supported | call Is(filter(HintLines(), 'v:val[0] != 1'), [], 'still all above line 1') | endif
:call Is(&modified, 0, 'drawing them does not leave the list modified')

:call Describe('the hints name a configured delete command')
:call Reset()
:let g:editable_buffer_list_delete_command = 'KeepWindowsDelete'
:edit a.txt
:BufferList
:if g:hints_supported | call Ok(join(Hints()) =~# 'delete lines to :KeepWindowsDelete', 'the configured command is shown') | endif
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
:vertical resize 30
:BufferList
:let g:narrow = Hints()
:if g:hints_supported | call Ok(len(g:narrow) > 2, 'a narrow window gets more than two lines') | endif
:if g:hints_supported | call Is(filter(copy(g:narrow), 'strdisplaywidth(v:val) > winwidth(0)'), [], 'none wider than the window') | endif
:if g:hints_supported | call Ok(join(g:narrow) =~# ':h :ls', 'the end of the legend is still there') | endif
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

:call Finish()
