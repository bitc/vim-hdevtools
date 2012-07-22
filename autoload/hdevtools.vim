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
