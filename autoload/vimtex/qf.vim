" VimTeX - LaTeX plugin for Vim
"
" Maintainer: Karl Yngve Lervåg
" Email:      karl.yngve@gmail.com
"

function! vimtex#qf#init_buffer() abort " {{{1
  if !g:vimtex_quickfix_enabled | return | endif

  command! -buffer VimtexErrors  call vimtex#qf#toggle()

  nnoremap <buffer> <plug>(vimtex-errors)  :call vimtex#qf#toggle()<cr>
endfunction

" }}}1
function! vimtex#qf#init_state(state) abort " {{{1
  if !g:vimtex_quickfix_enabled | return | endif

  try
    let l:qf = vimtex#qf#{g:vimtex_quickfix_method}#new()
    call l:qf.init(a:state)
    unlet l:qf.init
    let a:state.qf = l:qf
  catch /VimTeX: Requirements not met/
    call vimtex#log#warning(
          \ 'Quickfix state not initialized!',
          \ 'Please see :help g:vimtex_quickfix_method')
  endtry
endfunction

" }}}1

function! vimtex#qf#toggle() abort " {{{1
  if vimtex#qf#is_open()
    cclose
  else
    call vimtex#qf#open(1)
  endif
endfunction

" }}}1
function! vimtex#qf#open(force) abort " {{{1
  if !exists('b:vimtex.qf.addqflist') | return | endif

  try
    call vimtex#qf#setqflist()
  catch /VimTeX: No log file found/
    if a:force
      call vimtex#log#warning('No log file found')
    endif
    if g:vimtex_quickfix_mode > 0
      cclose
    endif
    return
  catch
    call vimtex#log#error(
          \ 'Something went wrong when parsing log files!',
          \ v:exception)
    if g:vimtex_quickfix_mode > 0
      cclose
    endif
    return
  endtry

  if empty(getqflist())
    if a:force
      call vimtex#log#info('No errors!')
    endif
    if g:vimtex_quickfix_mode > 0
      cclose
    endif
    return
  endif

  "
  " There are two options that determine when to open the quickfix window.  If
  " forced, the quickfix window is always opened when there are errors or
  " warnings (forced typically imply that the functions is called from the
  " normal mode mapping).  Else the behaviour is based on the settings.
  "
  let l:errors_or_warnings = s:qf_has_errors()
        \ || g:vimtex_quickfix_open_on_warning

  if a:force || (g:vimtex_quickfix_mode > 0 && l:errors_or_warnings)
    let s:previous_window = win_getid()
    botright cwindow
    if g:vimtex_quickfix_mode == 2
      redraw
      call win_gotoid(s:previous_window)
    endif
    if g:vimtex_quickfix_autoclose_after_keystrokes > 0
      augroup vimtex_qf_autoclose
        autocmd!
        autocmd CursorMoved,CursorMovedI * call s:qf_autoclose_check()
      augroup END
    endif
    redraw
  endif
endfunction

" }}}1
function! vimtex#qf#setqflist(...) abort " {{{1
  if !exists('b:vimtex.qf.addqflist') | return | endif

  if a:0 > 0 && !empty(a:1)
    let l:tex = a:1
    let l:log = fnamemodify(l:tex, ':r') . '.log'
    let l:blg = fnamemodify(l:tex, ':r') . '.blg'
    let l:jump = 0
  else
    let l:tex = b:vimtex.tex
    let l:log = b:vimtex.compiler.get_file('log')
    let l:blg = b:vimtex.compiler.get_file('blg')
    let l:jump = g:vimtex_quickfix_autojump
  endif

  try
    " Initialize the quickfix list
    " Note: Only create new list if the current list is not a VimTeX qf list
    if get(getqflist({'title': 1}), 'title') =~# 'VimTeX'
      call setqflist([], 'r')
    else
      call setqflist([])
    endif

    " Parse LaTeX errors
    call b:vimtex.qf.addqflist(l:tex, l:log)

    " Parse bibliography errors
    if has_key(b:vimtex.packages, 'biblatex')
      call vimtex#qf#biblatex#addqflist(l:blg)
    else
      call vimtex#qf#bibtex#addqflist(l:blg)
    endif

    " Ignore entries if desired
    if !empty(g:vimtex_quickfix_ignore_filters)
      let l:qflist = getqflist()
      for l:re in g:vimtex_quickfix_ignore_filters
        call filter(l:qflist, 'v:val.text !~# l:re')
      endfor
      call setqflist(l:qflist, 'r')
    endif

    " Put errors on top
    let l:qflist = getqflist()
    call setqflist(l:qflist->sort({ q1, q2 ->
          \ (q2.type ==? 'e' ? 1 : 0) - (q1.type ==? 'e' ? 1 : 0)
          \}), 'r')

    " Set title if supported
    try
      call setqflist([], 'r', {'title': 'VimTeX errors (' . b:vimtex.qf.name . ')'})
    catch
    endtry

    " Jump to first error if wanted
    if l:jump
      cfirst
    endif

    " Highlight undefined control sequences in source buffers
    call s:highlight_ucs()
  catch /VimTeX: No log file found/
    throw 'VimTeX: No log file found'
  endtry
endfunction

" }}}1
function! vimtex#qf#inquire(file) abort " {{{1
  try
    call vimtex#qf#setqflist(a:file)
    return s:qf_has_errors()
  catch
    return 0
  endtry
endfunction

" }}}1

function! vimtex#qf#is_open() abort " {{{1
  redir => l:bufstring
  silent! ls!
  redir END

  let l:buflist = filter(split(l:bufstring, '\n'), 'v:val =~# ''Quickfix''')

  for l:line in l:buflist
    let l:bufnr = str2nr(matchstr(l:line, '^\s*\zs\d\+'))
    if bufwinnr(l:bufnr) >= 0
          \ && getbufvar(l:bufnr, '&buftype', '') ==# 'quickfix'
      return 1
    endif
  endfor

  return 0
endfunction

" }}}1


function! s:qf_has_errors() abort " {{{1
  return len(filter(getqflist(), 'v:val.type ==# ''E''')) > 0
endfunction

" }}}1
function! s:qf_autoclose_check() abort " {{{1
  " Avoid this check if command-line window is open
  " See :help E11
  if bufexists("[Command Line]") | return | endif

  if get(s:, 'keystroke_counter') == 0
    let s:keystroke_counter = g:vimtex_quickfix_autoclose_after_keystrokes
  endif

  let l:qf_winnr = map(
        \ filter(getwininfo(),
        \   {_, x -> x.tabnr == tabpagenr() && x.quickfix && !x.loclist}),
        \ {_, x -> x.winnr})

  if empty(l:qf_winnr)
    let s:keystroke_counter = 0
  elseif l:qf_winnr[0] == winnr()
    let s:keystroke_counter = g:vimtex_quickfix_autoclose_after_keystrokes + 1
  else
    let s:keystroke_counter -= 1
  endif

  if s:keystroke_counter == 0
    cclose
    autocmd! vimtex_qf_autoclose
    augroup! vimtex_qf_autoclose
  endif
endfunction

" }}}1


function! s:highlight_ucs() abort " {{{1
  call s:highlight_ucs_clear()

  if !g:vimtex_quickfix_highlight_ucs | return | endif

  for l:qf in getqflist()
    if l:qf.text !~# 'Undefined control sequence' | continue | endif
    if l:qf.bufnr <= 0 | continue | endif

    " Extract the undefined command: the last \word at the end of the text.
    " The qf text includes the 'l.N ...<context> \cmd' continuation line, so
    " the undefined command is the rightmost \word token.
    let l:cmd = matchstr(l:qf.text, '\\\w\+\ze\s*$')
    if empty(l:cmd) | continue | endif

    " Find the rightmost occurrence of the command on that source line
    let l:srcline = get(getbufline(l:qf.bufnr, l:qf.lnum), 0, '')
    let l:pat = '\\' . escape(l:cmd[1:], '.*[]^$~\') . '\>'
    let l:col = -1
    let l:pos = 0
    while 1
      let l:m = match(l:srcline, l:pat, l:pos)
      if l:m < 0 | break | endif
      let l:col = l:m
      let l:pos = l:m + 1
    endwhile
    if l:col < 0 | continue | endif

    call s:highlight_ucs_add(l:qf.bufnr, l:qf.lnum, l:col + 1, len(l:cmd))
  endfor
endfunction

" }}}1
function! s:highlight_ucs_clear() abort " {{{1
  if has('nvim')
    for l:bufnr in get(s:, 'ucs_buffers', [])
      if bufexists(l:bufnr)
        call nvim_buf_clear_namespace(l:bufnr, s:highlight_ucs_ns(), 0, -1)
      endif
    endfor
  else
    for l:item in get(s:, 'ucs_props', [])
      if bufexists(l:item.bufnr)
        silent! call prop_remove(
              \ {'type': 'VimtexQfUndefinedCmd', 'bufnr': l:item.bufnr},
              \ l:item.lnum)
      endif
    endfor
    let s:ucs_props = []
  endif
  let s:ucs_buffers = []
endfunction

" }}}1
function! s:highlight_ucs_add(bufnr, lnum, col, len) abort " {{{1
  if has('nvim')
    call nvim_buf_set_extmark(a:bufnr, s:highlight_ucs_ns(), a:lnum - 1, a:col - 1, {
          \ 'end_col': a:col - 1 + a:len,
          \ 'hl_group': 'VimtexQfUndefinedCmd',
          \})
  else
    if empty(prop_type_get('VimtexQfUndefinedCmd'))
      call prop_type_add('VimtexQfUndefinedCmd',
            \ {'highlight': 'VimtexQfUndefinedCmd', 'combine': 1})
    endif
    silent! call prop_add(a:lnum, a:col, {
          \ 'length': a:len,
          \ 'type': 'VimtexQfUndefinedCmd',
          \ 'bufnr': a:bufnr,
          \})
    let s:ucs_props = get(s:, 'ucs_props', [])
    call add(s:ucs_props, {'bufnr': a:bufnr, 'lnum': a:lnum})
  endif
  let s:ucs_buffers = get(s:, 'ucs_buffers', [])
  if index(s:ucs_buffers, a:bufnr) < 0
    call add(s:ucs_buffers, a:bufnr)
  endif
endfunction

" }}}1
function! s:highlight_ucs_ns() abort " {{{1
  if !exists('s:ucs_ns')
    let s:ucs_ns = nvim_create_namespace('vimtex_ucs')
  endif
  return s:ucs_ns
endfunction

" }}}1
