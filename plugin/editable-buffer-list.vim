" editable-buffer-list.vim - the buffer list as an editable buffer
" Maintainer: Yogesh Dhamija <yogeshdhamija@outlook.com>
" Version 0.1

if(exists("g:loaded_editable_buffer_list"))
    finish
endif
let g:loaded_editable_buffer_list = 1

command! -bar BufferList call editableBufferList#Open()
