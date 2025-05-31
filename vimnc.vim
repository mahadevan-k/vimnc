" File: ~/.vim/plugin/vfm.vim
if exists("g:loaded_vfm")
  finish
endif
let g:loaded_vfm = 1


highlight VNCSelected ctermfg=yellow guifg=Yellow

function! s:human_readable_size(size)
  if a:size < 1024
    return a:size . 'B'
  elseif a:size < 1024 * 1024
    return printf('%.1fK', a:size / 1024)
  elseif a:size < 1024 * 1024 * 1024
    return printf('%.1fM', a:size / (1024 * 1024))
  else
    return printf('%.1fG', a:size / (1024 * 1024 * 1024))
  endif
endfunction

function! s:show_file_info()
  let l:path = s:get_cursor_path()
  if filereadable(l:path) || isdirectory(l:path)
    let l:info = system('ls -ld ' . shellescape(l:path))
    echo substitute(l:info, '\n', '', '')
  else
    echo "Not a valid file or directory"
  endif
endfunction

function! s:refresh_dir()
  let b:current_dir = fnamemodify(b:current_dir, ':p')
  let l:files = glob(s:join_path(b:current_dir,'/*'), 0, 1)
  let l:lines = []

  setlocal modifiable

  for f in l:files
    let l:perm = getfperm(f)
    let l:size = getfsize(f)
    if l:size < 0
      let l:size_str = '?'
    else
      let l:size_str = s:human_readable_size(size)
    endif
    if isdirectory(f)
      let l:ftypechar="/"
    else
      let l:ftypechar="-"
    endif
    let l:name = fnamemodify(f, ':t')
    call add(l:lines, printf('%s %8s %s %s', l:perm, l:size_str, l:ftypechar, l:name))
  endfor

  %delete _
  call setline(1, l:lines)
  call cursor(1, 1)
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nowrap
  setlocal nomodifiable
endfunction

command! VimNC call s:open_file_manager()

function! s:show_help()
  belowright new
  resize 13
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal filetype=helptext " custom filetype not used by file manager

  " Insert your help text
  call append(0, [
        \ 'Vim File Manager Help:',
        \ '',
        \ '  h/j/k/l     - Navigate filesystem ',
        \ '  Enter   - Open file',
        \ '  Space   - select/unselect',
        \ '  x       - cut selected',
        \ '  y       - copy selected',
        \ '  p       - paste',
        \ '  d       - delete selection',
        \ '  a       - create folder',
        \ '  c       - rename',
        \ '  ?       - Toggle help'
        \ ])
  normal! gg
  nnoremap <buffer> ? :close<CR>
endfunction

function! s:leave_buffer()
  call s:clear_buffers()
  call s:copy_selection()
  call s:refresh_dir()
endfunction


function! s:open_file_manager()
  vnew
  setlocal filetype=vfm
  let b:current_dir = getcwd()
  let b:selection = {}
  let b:selection_matches = {}
  let b:yank_buffer = []
  let b:cut_buffer = []


  call s:refresh_dir()

  nnoremap <buffer> j j
  nnoremap <buffer> k k
  nnoremap <buffer> h :call <SID>go_up()<CR>
  nnoremap <buffer> l :call <SID>enter_dir()<CR>
  nnoremap <buffer> <space> :call <SID>toggle_select()<CR>
  nnoremap <buffer> y :call <SID>copy_selection()<CR>
  nnoremap <buffer> p :call <SID>paste_selection()<CR>
  nnoremap <buffer> d :call <SID>delete_selection()<CR>
  nnoremap <buffer> a :call <SID>create_folder()<CR>
  nnoremap <buffer> i :call <SID>show_file_info()<CR>
  nnoremap <buffer> x :call <SID>cut_selection()<CR>
  nnoremap <buffer> c :call <SID>rename()<CR>
  nnoremap <buffer> ? :call <SID>show_help()<CR>
  nnoremap <buffer> <CR> :call <SID>open_file()<CR>
 
  execute 'autocmd WinLeave <buffer> call <SID>leave_buffer()'

  echo "type ? for help"
endfunction

function! s:join_path(dir, file)
  return substitute(a:dir, '/\+$', '', '') . '/' . substitute(a:file, '^/\+', '', '')
endfunction

function! s:get_cursor_path()
  let l:line = getline('.')
  let l:parts = split(l:line)
  let l:filename = join(l:parts[3:],' ')
  return fnamemodify(s:join_path(b:current_dir,l:filename), ':p')
endfunction


" Navigate into directory
function! s:enter_dir()
  call s:clear_selection()
  let l:target = s:get_cursor_path()
  if isdirectory(l:target)
    let b:current_dir = l:target
    call s:refresh_dir()
  endif
endfunction

" Go up to parent
function! s:go_up()
  call s:clear_selection()
  let l:clean_dir = substitute(b:current_dir, '/\+$', '', '')
  let b:current_dir = fnamemodify(l:clean_dir, ':h')
  call s:refresh_dir()
endfunction

" Toggle selection
function! s:toggle_select()
  let l:path = s:get_cursor_path()
  let l:lnum = line('.')
  if has_key(b:selection, l:path)
    call remove(b:selection, l:path)
    call matchdelete(b:selection_matches[l:path])
  else
    let b:selection[l:path] = 1
    let b:selection_matches[l:path] = matchaddpos('VNCSelected', [l:lnum])
  endif
  echo 'Selected: ' . len(keys(b:selection))
endfunction

" clear selection
function! s:clear_selection()
  for key in keys(b:selection)
      call matchdelete(b:selection_matches[key])
  endfor
  let b:selection = {}
  let b:selection_matches = {}
endfunction

" Print selection
function! s:print_files(files)
  if empty(a:files)
    echo "No files selected."
    return
  endif

  echo "Selected files:"
  for l:path in a:files
    echo '  ' . l:path
  endfor
endfunction

function! s:print_selection()
  call s:print_files(keys(b:selection))
endfunction

function! s:print_buffers()
  call s:print_files(len(b:yank_buffer)==0 ? b:cut_buffer : b:yank_buffer)
endfunction

" Yank (copy)
function! s:copy_selection()
  let b:yank_buffer = copy(keys(b:selection))
  let b:cut_buffer = []
  echo 'Copied ' . len(b:yank_buffer) . ' items'
endfunction

function! s:cut_selection()
  let b:cut_buffer = copy(keys(b:selection))
  let b:yank_buffer = []
  echo 'Cut ' . len(b:cut_buffer) . ' items'
endfunction

function! s:clear_buffers()
  let b:yank_buffer=[]
  let b:cut_buffer=[]
endfunction


" Paste
function! s:paste_selection()
  let l:buffer = !empty(b:cut_buffer) ? b:cut_buffer : b:yank_buffer
  let l:is_cut = !empty(b:cut_buffer)

  if empty(l:buffer)
    echo "Nothing to paste"
    return
  endif
  let l:path=substitute(l:buffer[0],'/\+$','','')
  if l:path==s:join_path(b:current_dir,fnamemodify(l:path,':t'))
    echo "Nothing to do, same location!"
    return
  endif

  call s:print_buffers()
  let l:op = l:is_cut ? "Move" : "Copy"
  if confirm(l:op." here?", "&Yes\n&No", 2) != 1
    return
  endif
  let l:cmd = l:is_cut ? "mv" : "cp -r"
  for file in l:buffer
    if l:is_cut
      call system(l:cmd.' '.shellescape(file).' '.shellescape(b:current_dir).' 2>&1')
    else
      call system(l:cmd.' '.shellescape(file).' '.shellescape(b:current_dir).' 2>&1')
    endif
  endfor
  call s:clear_buffers()
  call s:clear_selection()
  call s:refresh_dir()
  echo 'Pasted.'
endfunction

" Delete
function! s:delete_selection()
  if empty(b:selection)
    echo "Nothing to delete"
    return
  endif
  call s:print_selection()
  if confirm("Really delete selected files?", "&Yes\n&No", 2) != 1
    return
  endif
  for file in keys(b:selection)
    call delete(file, 'rf')
  endfor
  call s:clear_buffers()
  call s:clear_selection()
  call s:refresh_dir()
  echo 'Deleted.'
endfunction

" mkdir
function! s:create_folder()
  let l:folder_name = input('New folder name: ')
  if empty(l:folder_name)
    echo "Cancelled: folder name empty."
    return
  endif

  let l:new_path = b:current_dir . '/' . l:folder_name

  if isdirectory(l:new_path) || filereadable(l:new_path)
    echohl ErrorMsg
    echo "Folder or file already exists!"
    echohl None
    return
  endif

  if confirm("Create folder '".l:folder_name."'?", "&Yes\n&No", 2) != 1
    echo "Cancelled."
    return
  endif

  try
    call mkdir(l:new_path, "p")
    echo "Folder '".l:folder_name."' created."
    call s:clear_selection()
    call s:refresh_dir()
  catch
    echohl ErrorMsg
    echo "Failed to create folder."
    echohl None
  endtry
endfunction

" rename
function! s:rename()
  let l:path = s:get_cursor_path()
  let l:file_name = input('New name: ')
  if empty(l:file_name)
    echo "Cancelled: new name empty."
    return
  endif

  let l:new_path = b:current_dir . '/' . l:file_name

  if isdirectory(l:new_path) || filereadable(l:new_path)
    echohl ErrorMsg
    echo "Folder or file already exists!"
    echohl None
    return
  endif

  if confirm("Reanme '".l:path."' to '".l:new_path."'?", "&Yes\n&No", 2) != 1
    echo "Cancelled."
    return
  endif

  try
    call rename(l:path,l:new_path)
    echo "Renamed to '".l:new_path."'."
    call s:clear_selection()
    call s:refresh_dir()
  catch
    echohl ErrorMsg
    echo "Failed to rename."
    echohl None
  endtry
endfunction

" open fie/folder
function! s:open_file()
  let l:path = s:get_cursor_path()
  set splitright
  execute 'vsplit' fnameescape(l:path)
endfunction
