if exists('b:did_ftplugin_hdevtools') && b:did_ftplugin_hdevtools
  finish
endif
let b:did_ftplugin_hdevtools = 1

if !exists('s:has_hdevtools')
  let s:has_hdevtools = 0

  if !executable('hdevtools')
    call hdevtools#print_error('hdevtools: hdevtools is not executable!')
    finish
  endif

  let s:has_hdevtools = 1
endif

if !s:has_hdevtools
  finish
endif

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= ' | '
else
  let b:undo_ftplugin = ''
endif

command! -buffer -nargs=0 HdevtoolsType echo hdevtools#type()[1]
command! -buffer -nargs=0 HdevtoolsClear call hdevtools#type_clear()
command! -buffer -nargs=? HdevtoolsInfo call hdevtools#info(<q-args>)

let b:undo_ftplugin .= join(map([
      \ 'HdevtoolsType',
      \ 'HdevtoolsClear',
      \ 'HdevtoolsInfo'
      \ ], '"delcommand " . v:val'), ' | ')
let b:undo_ftplugin .= ' | unlet b:did_ftplugin_hdevtools'


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" Functions
" 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
fun! DeleteSocketFile()
    if fileisreadable(".hdevtools.sock")
        system("rm .hdevtools.sock")
    endif
endfun


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" Autocommands
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
au VimEnter :call DeleteSocketFile()
au VimLeave :call DeleteSocketFile()
