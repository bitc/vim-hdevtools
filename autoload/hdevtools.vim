let s:hdevtools_info_buffer = -1

function! s:shutdown()
  let l:cmd = hdevtools#build_command_bare('admin', '--stop-server')
  " Must save the output in order for the command to actually run:
  let l:dummy = system(l:cmd)
endfunction

function! hdevtools#prepare_shutdown()
  let l:cmd = hdevtools#build_command_bare('admin', '--status')
  " Must save the output in order for the command to actually run:
  let l:dummy = system(l:cmd)

  " Only shutdown the hdevtools server on Vim quit if the above 'status'
  " command indicated that the hdevtools server isn't currently running: This
  " plugin will start the server, so this plugin should be responsible for
  " shutting it down when Vim exits.
  "
  " If on the other hand, the hdevtools server is already running, then we
  " shouldn't shut it down on Vim exit, since someone else started it, so it's
  " their problem.
  if v:shell_error != 0
    autocmd VimLeave * call s:shutdown()
  endif
endfunction

function! hdevtools#go_file(opencmd)
  " Get the import declaration under the cursor
  let l:module_name = matchstr(getline("."), '^import\s\+\(qualified\s\+\)\=\zs\(\w\|\.\)\+\ze')
  if l:module_name ==# ''
    call hdevtools#print_warning("Cursor not on a Haskell import declaration")
    return
  endif

  let l:cmd = hdevtools#build_command('modulefile', shellescape(l:module_name))
  let l:output = system(l:cmd)

  let l:lines = split(l:output, '\n')

  if v:shell_error != 0
    for l:line in l:lines
      call hdevtools#print_error(l:line)
    endfor
    return
  endif

  exe a:opencmd fnameescape(l:lines[0])
endfunction

function! hdevtools#info(identifier)
  let l:identifier = a:identifier

  if l:identifier ==# ''
    " No identifier argument given, probably called from a keyboard shortcut

    if bufnr('%') == s:hdevtools_info_buffer
      " The Info Window is already open and active, so simply close it and
      " finish
      call hdevtools#infowin_leave()
      return
    endif

    " Get the identifier under the cursor
    let l:identifier = s:extract_identifier(getline("."), col("."))
  endif

  if l:identifier ==# ''
    echo '-- No Identifier Under Cursor'
    return
  endif

  let l:file = expand('%')
  if l:file ==# ''
    call hdevtools#print_warning("current version of hdevtools.vim doesn't support running on an unnamed buffer.")
    return
  endif
  let l:cmd = hdevtools#build_command('info', shellescape(l:file) . ' -- ' . shellescape(l:identifier))
  let l:output = system(l:cmd)

  let l:lines = split(l:output, '\n')

  " Check if the call to hdevtools info succeeded
  if v:shell_error != 0
    for l:line in l:lines
      call hdevtools#print_error(l:line)
    endfor
    return
  endif

  " Create a new window
  call s:infowin_create("(" . l:identifier . ")")

  " Adjust the height of the Info Window so that all lines will fit
  exe 'resize ' (len(l:lines) + 1)

  " The result returned from the 'info' command is very similar to regular
  " haskell code, so Haskell syntax highlighting looks good on it
  setlocal filetype=haskell

  " Fill the contents of the Info Window with the result
  setlocal modifiable
  call append(0, l:lines)
  setlocal nomodifiable

  " Jump the cursor to the beginning of the buffer
  normal gg

  " Look for the first line containing a reference to a file and jump the
  " cursor to it if found
  for l:i in range(0, len(l:lines)-1)
    if match(l:lines[l:i], '-- Defined at \S\+:\d\+:\d\+') >= 0
      call setpos(".", [0, l:i + 1, 1, 0])
      break
    endif
  endfor

  " Apply syntax highlighting for these comments: -- Defined at Hello.hs:12:5
  " These are turned into links that can be jumped to
  syntax match HdevtoolsInfoLink '-- Defined at \zs\S\+:\d\+:\d\+' containedin=ALL contained
  highlight link HdevtoolsInfoLink Underlined
endfunction

function! s:extract_identifier(line_text, col)
  if a:col > len(a:line_text)
    return ''
  endif

  let l:index = a:col - 1
  let l:delimiter = '\s\|[(),;`{}"[\]]'

  " Move the index forward till the cursor is not on a delimiter
  while match(a:line_text[l:index], l:delimiter) == 0
    let l:index = l:index + 1
    if l:index == len(a:line_text)
      return ''
    endif
  endwhile

  let l:start_index = l:index
  " Move start_index backwards until it hits a delimiter or beginning of line
  while l:start_index > 0 && match(a:line_text[l:start_index-1], l:delimiter) < 0
    let l:start_index = l:start_index - 1
  endwhile

  let l:end_index = l:index
  " Move end_index forwards until it hits a delimiter or end of line
  while l:end_index < len(a:line_text) - 1 && match(a:line_text[l:end_index+1], l:delimiter) < 0
    let l:end_index = l:end_index + 1
  endwhile

  let l:fragment = a:line_text[l:start_index : l:end_index]
  let l:index = l:index - l:start_index

  let l:results = []

  let l:name_regex = '\(\u\(\w\|''\)*\.\)*\(\a\|_\)\(\w\|''\)*'
  let l:operator_regex = '\(\u\(\w\|''\)*\.\)*\(\\\|[-!#$%&*+./<=>?@^|~:]\)\+'

  " Perform two passes over the fragment(one for finding a name, and the other
  " for finding an operator). Each pass tries to find a match that has the
  " cursor contained within it.
  for l:regex in [l:name_regex, l:operator_regex]
    let l:remainder = l:fragment
    let l:rindex = l:index
    while 1
      let l:i = match(l:remainder, l:regex)
      if l:i < 0
        break
      endif
      let l:result = matchstr(l:remainder, l:regex)
      let l:end = l:i + len(l:result)
      if l:i <= l:rindex && l:end > l:rindex
        call add(l:results, l:result)
        break
      endif
      let l:remainder = l:remainder[l:end :]
      let l:rindex = l:rindex - l:end
    endwhile
  endfor

  " There can be at most 2 matches(one from each pass). The longest one is the
  " correct one.
  if len(l:results) == 0
    return ''
  elseif len(l:results) == 1
    return l:results[0]
  else
    if len(l:results[0]) > len(l:results[1])
      return l:results[0]
    else
      return l:results[1]
    endif
  endif
endfunction

" Unit Test
function! hdevtools#test_extract_identifier()
  let l:tests = [
        \ 'let #foo# = 5',
        \ '#main#',
        \ '1 #+# 1',
        \ '1#+#1',
        \ 'blah #Foo.Bar# blah',
        \ 'blah #Foo.bar# blah',
        \ 'blah #foo#.Bar blah',
        \ 'blah #foo#.bar blah',
        \ 'blah foo#.#Bar blah',
        \ 'blah foo#.#bar blah',
        \ 'blah foo.#bar# blah',
        \ 'blah foo.#Bar# blah',
        \ 'blah #A.B.C.d# blah',
        \ '#foo#+bar',
        \ 'foo+#bar#',
        \ '#Foo#+bar',
        \ 'foo+#Bar#',
        \ '#Prelude..#',
        \ '[#foo#..bar]',
        \ '[foo..#bar#]',
        \ '#Foo.bar#',
        \ '#Foo#*bar',
        \ 'Foo#*#bar',
        \ 'Foo*#bar#',
        \ '#Foo.foo#.bar',
        \ 'Foo.foo#.#bar',
        \ 'Foo.foo.#bar#',
        \ '"a"#++#"b"',
        \ '''a''#<#''b''',
        \ '#Foo.$#',
        \ 'foo.#Foo.$#',
        \ '#-#',
        \ '#/#',
        \ '#\#',
        \ '#@#'
        \ ]
  for l:test in l:tests
    let l:expected = matchstr(l:test, '#\zs.*\ze#')
    let l:input = substitute(l:test, '#', '', 'g')
    let l:start_index = match(l:test, '#') + 1
    let l:end_index = match(l:test, '\%>' . l:start_index . 'c#') - 1
    for l:i in range(l:start_index, l:end_index)
      let l:result = s:extract_identifier(l:input, l:i)
      if l:expected !=# l:result
        call hdevtools#print_error("TEST FAILED expected: (" . l:expected . ") got: (" . l:result . ") for column " . l:i . " of: " . l:input)
      endif
    endfor
  endfor
endfunction

" ----------------------------------------------------------------------------
" The window code below was adapted from the 'Command-T' plugin, with major
" changes (and translated from the original Ruby)
"
" Command-T:
"     https://wincent.com/products/command-t/

function! s:infowin_create(window_title)
  let s:initial_window = winnr()
  call s:window_dimensions_save()

  " The following settings are global, so they must be saved before being
  " changed so that they can be later restored.
  " If you add to the code below changes to additional global settings, then
  " you must also appropriately modify s:settings_save and s:settings_restore
  call s:settings_save()
  set noinsertmode     " don't make Insert mode the default
  set report=9999      " don't show 'X lines changed' reports
  set sidescroll=0     " don't sidescroll in jumps
  set sidescrolloff=0  " don't sidescroll automatically
  set noequalalways    " don't auto-balance window sizes

  " The following settings are local so they don't have to be saved
  exe 'silent! botright 1split' fnameescape(a:window_title)
  setlocal bufhidden=unload  " unload buf when no longer displayed
  setlocal buftype=nofile    " buffer is not related to any file
  setlocal nomodifiable      " prevent manual edits
  setlocal noswapfile        " don't create a swapfile
  setlocal nowrap            " don't soft-wrap
  setlocal nonumber          " don't show line numbers
  setlocal nolist            " don't use List mode (visible tabs etc)
  setlocal foldcolumn=0      " don't show a fold column at side
  setlocal foldlevel=99      " don't fold anything
  setlocal nocursorline      " don't highlight line cursor is on
  setlocal nospell           " spell-checking off
  setlocal nobuflisted       " don't show up in the buffer list
  setlocal textwidth=0       " don't hard-wrap (break long lines)

  " Save the buffer number of the Info Window for later
  let s:hdevtools_info_buffer = bufnr("%")

  " Key bindings for the Info Window
  nnoremap <silent> <buffer> <CR> :call hdevtools#infowin_jump()<CR>
  nnoremap <silent> <buffer> <C-CR> :call hdevtools#infowin_jump('sp')<CR>
  nnoremap <silent> <buffer> <ESC> :call hdevtools#infowin_leave()<CR>

  " perform cleanup using an autocmd to ensure we don't get caught out by some
  " unexpected means of dismissing or leaving the Info Window (eg. <C-W q>,
  " <C-W k> etc)
  autocmd! * <buffer>
  autocmd BufLeave <buffer> silent! call hdevtools#infowin_leave()
  autocmd BufUnload <buffer> silent! call s:infowin_unload()
endfunction

function! s:settings_save()
  " The following must be in sync with settings_restore
  let s:original_settings = [
        \ &report,
        \ &sidescroll,
        \ &sidescrolloff,
        \ &equalalways,
        \ &insertmode
        \ ]
endfunction

function! s:settings_restore()
  " The following must be in sync with settings_save
  let &report = s:original_settings[0]
  let &sidescroll = s:original_settings[1]
  let &sidescrolloff = s:original_settings[2]
  let &equalalways = s:original_settings[3]
  let &insertmode = s:original_settings[4]
endfunction

function! s:window_dimensions_save()
  " Each element of the list s:window_dimensions is a list of 3 integers of
  " the form: [id, width, height]
  let s:window_dimensions = []
  for l:i in range(1, winnr("$"))
    call add(s:window_dimensions, [l:i, winwidth(i), winheight(i)])
  endfor
endfunction

" Used in s:window_dimensions_restore for sorting the windows
function! hdevtools#compare_window(i1, i2)
  " Compare the window heights:
  if a:i1[2] < a:i2[2]
    return 1
  elseif a:i1[2] > a:i2[2]
    return -1
  endif
  " The heights were equal, so compare the widths:
  if a:i1[1] < a:i2[1]
    return 1
  elseif a:i1[1] > a:i2[1]
    return -1
  endif
  " The widths were also equal:
  return 0
endfunction

function! s:window_dimensions_restore()
  " sort from tallest to shortest, tie-breaking on window width
  call sort(s:window_dimensions, "hdevtools#compare_window")

  " starting with the tallest ensures that there are no constraints preventing
  " windows on the side of vertical splits from regaining their original full
  " size
  for l:i in s:window_dimensions
    let l:id = l:i[0]
    let l:width = l:i[1]
    let l:height = l:i[2]
    exe l:id . "wincmd w"
    exe "resize" l:height
    exe "vertical resize" l:width
  endfor
endfunction

function! hdevtools#infowin_leave()
  call s:infowin_close()
  call s:infowin_unload()
  let s:hdevtools_info_buffer = -1
endfunction

function! s:infowin_unload()
  call s:window_dimensions_restore()
  call s:settings_restore()
  exe s:initial_window . "wincmd w"
endfunction

function! s:infowin_close()
  exe "silent! bunload!" s:hdevtools_info_buffer
endfunction

" Jumps to the location under the cursor.
"
" An single optional argument is allowed, which is a string command for
" opening a window, for example 'split' or 'vsplit'.
"
" If no argument is supplied then the default is to try to reuse the existing
" window (using 'edit') unless it is unsaved and cannot be changed, in which
" case 'split' is used
function! hdevtools#infowin_jump(...)
  " Search for the filepath, line and column in the current line that matches
  " the format: -- Defined at Hello.hs:12:5
  let l:line = getline(".")
  let l:m = matchlist(line, '-- Defined at \(\S\+\):\(\d\+\):\(\d\+\)')

  if len(l:m) == 0
    " No match found on the current line
    return
  endif

  " Extract the values from the result of the previous regex
  let l:filepath = l:m[1]
  let l:row = l:m[2]
  let l:col = l:m[3]

  " Get rid of the Info Window; the user doesn't need it anymore
  call hdevtools#infowin_leave()

  " Open the file in a window as appropriate
  if a:0 > 0 && a:1 !=# ''
    exe "silent" a:1 fnameescape(l:filepath)
  else
    if l:filepath !=# bufname("%")
      if !&hidden && &modified
        let l:opencmd = "sp"
      else
        let l:opencmd = "e"
      endif
      exe "silent" l:opencmd fnameescape(l:filepath)
    endif
  endif

  " Jump the cursor to the position from the 'Defined at'
  call setpos(".", [0, l:row, l:col, 0])
endfunction

" ----------------------------------------------------------------------------
" Most of the code below has been taken from ghcmod-vim, with a few
" adjustments and tweaks.
"
" ghcmod-vim:
"     https://github.com/eagletmt/ghcmod-vim/

let s:hdevtools_type = {
      \ 'ix': 0,
      \ 'types': [],
      \ }

function! s:hdevtools_type.spans(line, col)
  if empty(self.types)
    return 0
  endif
  let [l:line1, l:col1, l:line2, l:col2] = self.types[self.ix][0]
  return l:line1 <= a:line && a:line <= l:line2 && l:col1 <= a:col && a:col <= l:col2
endfunction

function! s:hdevtools_type.type()
  return self.types[self.ix]
endfunction

function! s:hdevtools_type.incr_ix()
  let self.ix = (self.ix + 1) % len(self.types)
endfunction

function! s:hdevtools_type.highlight(group)
  if empty(self.types)
    return
  endif
  call hdevtools#clear_highlight()
  let [l:line1, l:col1, l:line2, l:col2] = self.types[self.ix][0]
  let w:hdevtools_type_matchid = matchadd(a:group, '\%' . l:line1 . 'l\%' . l:col1 . 'c\_.*\%' . l:line2 . 'l\%' . l:col2 . 'c')
endfunction

function! s:highlight_group()
  return get(g:, 'hdevtools_type_highlight', 'Visual')
endfunction

function! s:on_enter()
  if exists('b:hdevtools_type')
    call b:hdevtools_type.highlight(s:highlight_group())
  endif
endfunction

function! s:on_leave()
  call hdevtools#clear_highlight()
endfunction

function! hdevtools#build_command(command, args)
  let l:cmd = 'hdevtools'
  let l:cmd = l:cmd . ' ' . a:command . ' '

  let l:cmd = l:cmd . get(g:, 'hdevtools_options', '') . ' '
  let l:cmd = l:cmd . a:args
  return l:cmd
endfunction

" Does not include g:hdevtools_options
function! hdevtools#build_command_bare(command, args)
  let l:cmd = 'hdevtools'
  let l:cmd = l:cmd . ' ' . a:command . ' '
  let l:cmd = l:cmd . a:args
  return l:cmd
endfunction

function! hdevtools#clear_highlight()
  if exists('w:hdevtools_type_matchid')
    call matchdelete(w:hdevtools_type_matchid)
    unlet w:hdevtools_type_matchid
  endif
endfunction

function! hdevtools#type()
  if &l:modified
    call hdevtools#print_warning('hdevtools#type: the buffer has been modified but not written')
  endif
  let l:line = line('.')
  let l:col = col('.')
  if exists('b:hdevtools_type') && b:hdevtools_type.spans(l:line, l:col)
    call b:hdevtools_type.incr_ix()
    call b:hdevtools_type.highlight(s:highlight_group())
    return b:hdevtools_type.type()
  endif

  let l:file = expand('%')
  if l:file ==# ''
    call hdevtools#print_warning("current version of hdevtools.vim doesn't support running on an unnamed buffer.")
    return ['', '']
  endif
  let l:cmd = hdevtools#build_command('type', shellescape(l:file) . ' ' . l:line . ' ' . l:col)
  let l:output = system(l:cmd)

  if v:shell_error != 0
    for l:line in split(l:output, '\n')
      call hdevtools#print_error(l:line)
    endfor
    return
  endif

  let l:types = []
  for l:line in split(l:output, '\n')
    let l:m = matchlist(l:line, '\(\d\+\) \(\d\+\) \(\d\+\) \(\d\+\) "\([^"]\+\)"')
    call add(l:types, [l:m[1 : 4], l:m[5]])
  endfor

  call hdevtools#clear_highlight()

  let l:len = len(l:types)
  if l:len == 0
    return [0, '-- No Type Information']
  endif

  let b:hdevtools_type = deepcopy(s:hdevtools_type)

  let b:hdevtools_type.types = l:types
  let l:ret = b:hdevtools_type.type()
  let [l:line1, l:col1, l:line2, l:col2] = l:ret[0]
  call b:hdevtools_type.highlight(s:highlight_group())

  augroup hdevtools-type-highlight
    autocmd! * <buffer>
    autocmd BufEnter <buffer> call s:on_enter()
    autocmd WinEnter <buffer> call s:on_enter()
    autocmd BufLeave <buffer> call s:on_leave()
    autocmd WinLeave <buffer> call s:on_leave()
  augroup END

  return l:ret
endfunction

function! hdevtools#type_clear()
  if exists('b:hdevtools_type')
    call hdevtools#clear_highlight()
    unlet b:hdevtools_type
  endif
endfunction

function! hdevtools#print_error(msg)
  echohl ErrorMsg
  echomsg a:msg
  echohl None
endfunction

function! hdevtools#print_warning(msg)
  echohl WarningMsg
  echomsg a:msg
  echohl None
endfunction
