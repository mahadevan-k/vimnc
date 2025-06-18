" File: ~/.vim/plugin/vimnc.vim
"
if exists("g:loaded_vimnc")
  finish
endif
let g:loaded_vimnc = 1


highlight VNCSelected ctermfg=yellow guifg=Yellow

if has('win32') || has('win64') || has('win95') || has('win16')
  let s:sep = '\'
  let s:rsep = '\\'
else
  let s:sep = '/'
  let s:rsep = '/'
endif

function s:get_linux_path(path)
  return substitute(a:path, s:rsep, '/', 'g')
endfunction

function! s:get_os_path(path)
  return substitute(a:path, '/', s:rsep, 'g')
endfunction

function s:trim_dir(path)
  return substitute(a:path, '/\+$', '','') 
endfunction

function s:trim_file(path)
  return substitute(a:path, '^/\+', '','') 
endfunction

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
    let l:info = system('ls -ld ' . shellescape(s:get_os_path(l:path)))
    echo substitute(l:info, '\n', '', '')
  else
    echo "Not a valid file or directory"
  endif
endfunction

function! s:set_cursor_location()
  if !exists('b:last_dir_name') || empty(b:last_dir_name)
    call cursor(1, 1)
  endif

  if exists('b:last_dir_name') && !empty(b:last_dir_name) && exists('b:is_going_up') && b:is_going_up
    let l:found = 0
    for l:lnum in range(3, line('$'))
      let l:line = getline(l:lnum)
      if l:line =~ '^.* ' . escape(b:last_dir_name . s:sep, '\/') . '$'
        call cursor(l:lnum, 1)
        let l:found = 1
        break
      endif
    endfor
    unlet b:last_dir_name
    unlet b:is_going_up
  endif
endfunction

function! s:refresh_dir()
  let b:current_dir = s:get_linux_path(fnamemodify(b:current_dir, ':p'))
  let l:files = glob(s:join_path(b:current_dir,'/*'), 0, 1)
  let l:lines = []

  setlocal modifiable

  if fnamemodify(b:current_dir, ':h') !=# b:current_dir
    call add(l:lines,'^ ..')
  endif
  call add(l:lines,'> ' . s:get_os_path(b:current_dir))

  for f in l:files
    let l:perm = getfperm(f)
    let l:size = getfsize(f)
    if l:size < 0
      let l:size_str = '?'
    else
      let l:size_str = s:human_readable_size(l:size)
    endif
    let l:name = fnamemodify(f, ':t')
    let l:ftypechar = isdirectory(f) ? s:sep : ''
    call add(l:lines, printf('%s %8s %s%s', l:perm, l:size_str, l:name, l:ftypechar))
  endfor

  %delete _
  call setline(1, l:lines)
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nowrap
  setlocal nomodifiable

  call s:set_cursor_location()

  echo 'type ? for help'
endfunction

command! VimNC call s:open_file_manager()

function! s:show_help()
  belowright new
  resize 13
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal filetype=helptext

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
        \ '  r       - refresh directory',
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
  setlocal filetype=vimnc
  let b:current_dir = s:get_linux_path(getcwd())
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
  nnoremap <buffer> r :call <SID>refresh_dir()<CR>
endfunction

function! s:join_path(dir, file)
  return s:trim_dir(a:dir) . '/' . s:trim_file(a:file)
endfunction

function! s:get_cursor_path()
  let l:line = getline('.')
  if l:line =~ '^\^ \.\.$'
    let l:current_dir = s:trim_dir(b:current_dir)
    let l:parent_dir = fnamemodify(l:current_dir, ':h')
    let b:last_dir_name = fnamemodify(l:current_dir, ':t')
    let b:is_going_up = 1
    return l:parent_dir
  endif
  if l:line =~ '^>'
    return b:current_dir
  endif
  let l:parts = split(l:line)
  let l:filename = s:trim_dir(join(l:parts[2:], ' '))
  let l:path = s:join_path(b:current_dir, l:filename)
  return fnamemodify(l:path, ':p')
endfunction

function! s:enter_dir()
  call s:clear_selection()
  let l:target = s:get_cursor_path()
  if isdirectory(l:target)
    let b:current_dir = l:target
    call s:refresh_dir()
  endif
endfunction

function! s:go_up()
  call s:clear_selection()
  let l:clean_dir = s:trim_dir(b:current_dir)
  let l:parent_dir = fnamemodify(l:clean_dir, ':h')
  let b:last_dir_name =fnamemodify(l:clean_dir,':t')
  let b:is_going_up = 1
  let b:current_dir = l:parent_dir
  call s:refresh_dir()
endfunction

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

function! s:clear_selection()
  for key in keys(b:selection)
      call matchdelete(b:selection_matches[key])
  endfor
  let b:selection = {}
  let b:selection_matches = {}
endfunction

function! s:print_files(files)
  if empty(a:files)
    echo "No files selected."
    return
  endif

  echom "Selected files:"
  for l:path in a:files
    echom '  ' . s:get_os_path(l:path)
  endfor
endfunction

function! s:print_selection()
  call s:print_files(keys(b:selection))
endfunction

function! s:print_buffers()
  call s:print_files(len(b:yank_buffer)==0 ? b:cut_buffer : b:yank_buffer)
endfunction

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


function! s:paste_selection()
  let l:buffer = !empty(b:cut_buffer) ? b:cut_buffer : b:yank_buffer
  let l:is_cut = !empty(b:cut_buffer)

  if empty(l:buffer)
    echo "Nothing to paste"
    return
  endif

  let l:path=s:trim_dir(l:buffer[0])
  if l:path==s:join_path(b:current_dir, fnamemodify(l:path,':t'))
    echo "Nothing to do, same location!"
    return
  endif

  call s:print_buffers()
  let l:op = l:is_cut ? "Move" : "Copy"
  let l:choice = input(l:op." here? (y/n): ")
  if l:choice !~? '^y'
    return
  endif

  redraw!

  try
    let l:cmd = l:is_cut ? "mv" : "cp -r"
    for file in l:buffer
      if l:is_cut
        call system(l:cmd.' '.shellescape(s:get_os_path(file)).' '.shellescape(s:get_os_path(b:current_dir)).' 2>&1')
      else
        call system(l:cmd.' '.shellescape(s:get_os_path(file)).' '.shellescape(s:get_os_path(b:current_dir)).' 2>&1')
      endif
    endfor
    call s:clear_buffers()
    call s:clear_selection()
    call s:refresh_dir()
  catch
    echohl ErrorMsg
    echo "Failed to paste files."
    echohl None
  endtry
endfunction

function! s:delete_selection()
  if empty(b:selection)
    echo "Nothing to delete"
    return
  endif
  
  call s:print_selection()
  let l:choice = input("Really delete selected files? (y/n): ")
  if l:choice !~? '^y'
    return
  endif

  redraw!

  try
    for file in keys(b:selection)
      call delete(file, 'rf')
    endfor
    call s:clear_buffers()
    call s:clear_selection()
    call s:refresh_dir()
  catch
    echohl ErrorMsg
    echo "Failed to delete selected files."
    echohl None
  endtry
endfunction

function! s:create_folder()
  let l:folder_name = input('New folder name: ')
  if empty(l:folder_name)
    return
  endif

  let l:new_path = s:join_path(b:current_dir, l:folder_name)

  if isdirectory(l:new_path) || filereadable(l:new_path)
    echohl ErrorMsg
    echo "Folder or file already exists!"
    echohl None
    return
  endif

  let l:choice = input("Create folder '".l:folder_name."'? (y/n): ")
  if l:choice !~? '^y'
    return
  endif

  execute "redraw!"

  try
    call mkdir(l:new_path, "p")
    call s:clear_selection()
    call s:refresh_dir()
  catch
    echohl ErrorMsg
    echo "Failed to create folder."
    echohl None
  endtry
endfunction

function! s:rename()
  let l:path = s:get_cursor_path()
  let l:file_name = input('New name: ')
  if empty(l:file_name)
    return
  endif

  let l:new_path = s:join_path(b:current_dir, l:file_name)

  if isdirectory(l:new_path) || filereadable(l:new_path)
    echohl ErrorMsg
    echo "Folder or file already exists!"
    echohl None
    return
  endif

  let l:original_name = fnamemodify(l:path, ':t')
  if empty(l:original_name)
    let l:original_name = l:path
  endif

  let l:choice = input("Rename '".l:original_name."' to '".l:file_name."'? (y/n): ")
  if l:choice !~? '^y'
    return
  endif

  execute "redraw!"

  try
    call rename(l:path,l:new_path)
    call s:clear_selection()
    call s:refresh_dir()
  catch
    echohl ErrorMsg
    echo "Failed to rename."
    echohl None
  endtry
endfunction

function! s:open_file()
  let l:line = getline('.')
  if l:line =~ '^>'
    return
  endif
  
  let l:path = s:get_cursor_path()
  if isdirectory(l:path)
    let b:current_dir = l:path
    call s:refresh_dir()
  else
    set splitright
    execute 'vsplit' fnameescape(l:path)
  endif
endfunction
