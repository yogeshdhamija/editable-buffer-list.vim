" Loaded with -u, so it stands in for the whole vimrc.
"
" The tests live in driver.ex, not here. They have to be *typed* into Vim
" rather than sourced: TextChanged is checked when Vim returns to its main
" input loop, so a `dd` inside a sourced script or a function never fires it
" and the plugin never sees the edit. Only real keystrokes exercise the real
" path. run.sh feeds driver.ex in with `vim -s`; this file is just the
" scaffolding those keystrokes call into.

set nocompatible
set hidden
set noswapfile nobackup nowritebackup
" Nothing may ever wait for a keypress: the driver is a fixed keystroke
" stream, and a hit-enter prompt would eat the next test's input.
set nomore report=9999 shortmess=aoOtTWAIcFs noerrorbells belloff=all
execute 'set runtimepath^=' . fnameescape($EBL_ROOT)
runtime plugin/editable-buffer-list.vim

let g:pass = 0
let g:fail = 0
let g:log = []

" Flushed after every assertion, not just at the end: if the driver desyncs
" and Vim sits waiting for input that never comes, the partial file is the
" only evidence of how far the run got.
function! Flush() abort
    call writefile(g:log, 'result.txt')
endfunction

function! Describe(name) abort
    call add(g:log, '')
    call add(g:log, a:name)
    call Flush()
endfunction

function! Ok(cond, msg) abort
    if(a:cond)
        let g:pass += 1
        call add(g:log, '  ok    ' . a:msg)
    else
        let g:fail += 1
        call add(g:log, '  FAIL  ' . a:msg)
    endif
    call Flush()
endfunction

function! Is(got, want, msg) abort
    if(a:got ==# a:want)
        call Ok(1, a:msg)
    else
        call Ok(0, a:msg . '  [got ' . string(a:got) . ', want ' . string(a:want) . ']')
    endif
endfunction

function! Skip(msg) abort
    call add(g:log, '  skip  ' . a:msg)
    call Flush()
endfunction

" Each test starts from nothing, list buffers included.
function! Reset() abort
    silent! %bwipeout!
endfunction

" Call this before an edit in an ordinary buffer whose undo behaviour
" matters. The list needs none of it: its undo is the plugin's own, not Vim's.
"
" Interactive typing starts a fresh undo block per command. Input replayed
" from a script file arrives with no gap and can skip that boundary, so an
" edit merges into the one before it, and `u` steps back past both.
" Assigning 'undolevels' to itself forces the block break that real typing
" gets for free.
function! Sync() abort
    let &l:undolevels = &l:undolevels
endfunction

" \V so that a name like [Buffer List] is matched literally, not as a regex.
function! LineOf(name) abort
    return match(getline(1, '$'), '\V"' . escape(a:name, '\') . '"') + 1
endfunction

" :ls decorates a terminal's name with its job state -- `"!sleep [running]"` --
" so a terminal entry cannot be looked up by its bufname() the way a file can.
function! LineStarting(name) abort
    return match(getline(1, '$'), '\V"' . escape(a:name, '\')) + 1
endfunction

" The names in the current list, top to bottom.
function! Names() abort
    return map(getline(1, '$'), 'matchstr(v:val, ''"\zs.*\ze"'')')
endfunction

function! GotoEntry(name) abort
    let l:n = LineOf(a:name)
    call Ok(l:n > 0, 'the list has an entry for ' . a:name)
    if(l:n > 0)
        call cursor(l:n, 1)
    endif
endfunction

" For checking a list that is not the buffer we are focused on.
function! HasEntry(buf, name) abort
    return match(getbufline(a:buf, 1, '$'), '\V"' . escape(a:name, '\') . '"') >= 0
endfunction

function! ListBuffers() abort
    return filter(range(1, bufnr('$')), 'getbufvar(v:val, "&filetype") ==# "bufferlist"')
endfunction

" A job that will outlive the test, so :bdelete has something to refuse.
" 'hidden' matters more than it looks: a terminal opened in a window puts Vim
" into Terminal-Job mode, and every remaining keystroke in the driver would be
" typed into the job instead of into Vim. The buffer is still 'buflisted', so
" it shows up in the list either way.
function! StartTerm() abort
    let g:term = 0
    let g:term_supported = exists('*term_start') || exists('*termopen') || has('nvim-0.11')
    if(!g:term_supported)
        return
    endif
    try
        if(exists('*term_start'))
            let g:term = term_start(['sleep', '60'], {'hidden': 1})
        else
            " Neovim has no term_start, and its job takes over whatever buffer
            " is current, so give it a scratch one and step back off it.
            " jobstart's 'term' is preferred over termopen: termopen is
            " deprecated, and the warning it prints is exactly the kind of
            " message that eats a keystroke out of the driver.
            let l:here = bufnr('%')
            enew
            if(has('nvim-0.11'))
                call jobstart(['sleep', '60'], {'term': v:true})
            else
                call termopen(['sleep', '60'])
            endif
            let g:term = bufnr('%')
            execute 'buffer' l:here
        endif
    catch
        let g:term = 0
    endtry
endfunction

" Kill the job and get rid of the buffer in one go. Leaving Vim to notice the
" job died on its own produces a message *later*, at a hit-enter prompt that
" swallows a keystroke out of the driver and desyncs everything after it.
function! StopTerm() abort
    if(get(g:, 'term', 0) && bufexists(g:term))
        if(exists('*term_getjob'))
            silent! call job_stop(term_getjob(g:term), 'kill')
            silent! call term_wait(g:term, 50)
        endif
        " Wiping the buffer kills the job in either editor.
        silent! execute 'bwipeout!' g:term
    endif
    let g:term = 0
endfunction

" Same test as the plugin's: Neovim's extmarks, or Vim's text properties
" once they can go above a line and work with 'nowrap'.
let g:hints_supported = has('nvim-0.6') || (has('textprop') && has('patch-9.0.0451'))

" Every hint line in the current buffer as [lnum, text]: the line it is
" drawn above, and what it says.
function! HintLines() abort
    let l:found = []
    if(has('nvim'))
        " Returns the plugin's namespace, since it already exists.
        let l:ns = nvim_create_namespace('editable-buffer-list')
        for l:mark in nvim_buf_get_extmarks(0, l:ns, 0, -1, {'details': v:true})
            for l:chunks in get(l:mark[3], 'virt_lines', [])
                call add(l:found, [l:mark[1] + (get(l:mark[3], 'virt_lines_above') ? 1 : 2),
                    \ join(map(copy(l:chunks), 'v:val[0]'), '')])
            endfor
        endfor
    elseif(g:hints_supported && !empty(prop_type_get('bufferListHint')))
        " prop_list() gives text above a line last-drawn first: the opposite
        " of the order on screen, which is the order they were added in.
        for l:prop in reverse(prop_list(1, {'end_lnum': -1, 'types': ['bufferListHint']}))
            call add(l:found, [get(l:prop, 'text_align', '') ==# 'above' ? l:prop.lnum : -l:prop.lnum, l:prop.text])
        endfor
    endif
    return l:found
endfunction

" The highlight group of the hint chunk reading exactly a:text, or '' if
" there is none. Neovim only: in Vim a hint line has the one color.
function! HintGroup(text) abort
    let l:ns = nvim_create_namespace('editable-buffer-list')
    for l:mark in nvim_buf_get_extmarks(0, l:ns, 0, -1, {'details': v:true})
        for l:chunks in get(l:mark[3], 'virt_lines', [])
            for l:chunk in l:chunks
                if(l:chunk[0] ==# a:text)
                    return l:chunk[1]
                endif
            endfor
        endfor
    endfor
    return ''
endfunction

" What the hints above line 1 say, one string per line.
function! Hints() abort
    return map(filter(HintLines(), 'v:val[0] == 1'), 'v:val[1]')
endfunction

" The window options the list sets or leaves alone: [number, relativenumber,
" cursorline, signcolumn, cursorlineopt], leaving out 'signcolumn' and
" 'cursorlineopt' in a Vim built without them.
let g:has_signcolumn = exists('+signcolumn')
let g:has_culopt = exists('+cursorlineopt')
function! WinOpts() abort
    return [&l:number, &l:relativenumber, &l:cursorline]
        \ + (g:has_signcolumn ? [&l:signcolumn] : [])
        \ + (g:has_culopt ? [&l:cursorlineopt] : [])
endfunction
" What the tests set them to everywhere else with UsualOpts(): a gutter, and
" no 'cursorline' -- set, when it is on, to highlight only the line number,
" which on its own would not show the list's cursor row at all.
let g:usual_opts = [1, 1, 0] + (g:has_signcolumn ? ['yes'] : []) + (g:has_culopt ? ['number'] : [])
" What the list makes of them: the same gutter, and the row highlighted.
let g:list_opts = [1, 1, 1] + (g:has_signcolumn ? ['yes'] : []) + (g:has_culopt ? ['number,line'] : [])
function! UsualOpts() abort
    set number relativenumber nocursorline
    if(g:has_signcolumn)
        set signcolumn=yes
    endif
    if(g:has_culopt)
        set cursorlineopt=number
    endif
endfunction
function! DefaultOpts() abort
    set number& relativenumber& cursorline&
    if(g:has_signcolumn)
        set signcolumn&
    endif
    if(g:has_culopt)
        set cursorlineopt&
    endif
endfunction

" How many columns of the current window go to the gutter.
function! Textoff() abort
    return get(get(getwininfo(win_getid()), 0, {}), 'textoff', 0)
endfunction

" The lines the plugin highlights with a match in place of 'cursorline', as
" matchaddpos() positions: [[1]] or nothing.
function! CursorRowMatches() abort
    return map(filter(getmatches(), 'v:val.group ==# "CursorLine"'), 'v:val.pos1')
endfunction

" Stand-ins for g:editable_buffer_list_delete_command. Each records what it
" was asked to delete in g:deleted.
"
" KeepWindowsDelete does what vim-bbye or mini.bufremove do: every window
" showing the buffer is moved onto a fresh empty one first, so the :bdelete
" has no window left to close.
function! KeepWindowsDelete(buf) abort
    let l:buf = str2nr(a:buf)
    call add(g:deleted, l:buf)
    let l:here = win_getid()
    for l:winnr in range(1, winnr('$'))
        if(winbufnr(l:winnr) == l:buf)
            execute l:winnr . 'wincmd w'
            enew
        endif
    endfor
    call win_gotoid(l:here)
    execute 'bdelete' l:buf
endfunction
command! -nargs=1 KeepWindowsDelete call KeepWindowsDelete(<q-args>)
" Declines without an error, the way mini.bufremove does when its unsaved
" changes prompt is answered No.
command! -nargs=1 IgnoreDelete call add(g:deleted, str2nr(<q-args>))

function! Finish() abort
    call add(g:log, '')
    call add(g:log, printf('%d passed, %d failed', g:pass, g:fail))
    call writefile(g:log, 'result.txt')
    if(g:fail > 0)
        cquit
    endif
    qall!
endfunction
