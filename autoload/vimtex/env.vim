" VimTeX - LaTeX plugin for Vim
"
" Maintainer: Karl Yngve Lervåg
" Email:      karl.yngve@gmail.com
"

function! vimtex#env#init_buffer() abort " {{{1
  nnoremap <silent><buffer> <plug>(vimtex-env-change)
        \ :<c-u>call <sid>operator_setup('change', 'normal')<bar>normal! g@l<cr>

  nnoremap <silent><buffer> <plug>(vimtex-env-change-math)
        \ :<c-u>call <sid>operator_setup('change', 'math')<bar>normal! g@l<cr>

  nnoremap <silent><buffer> <plug>(vimtex-env-delete)
        \ :<c-u>call <sid>operator_setup('delete', 'normal')<bar>normal! g@l<cr>

  nnoremap <silent><buffer> <plug>(vimtex-env-delete-math)
        \ :<c-u>call <sid>operator_setup('delete', 'math')<bar>normal! g@l<cr>

  nnoremap <silent><buffer> <plug>(vimtex-env-toggle-star)
        \ :<c-u>call <sid>operator_setup('toggle_star', '')<bar>normal! g@l<cr>

  nnoremap <silent><buffer> <plug>(vimtex-env-toggle-math)
        \ :<c-u>call <sid>operator_setup('toggle_math', '')<bar>normal! g@l<cr>

  nnoremap <silent><buffer><expr> <plug>(vimtex-env-surround-operator)
        \ vimtex#env#surround_opfunc('operator')
  nmap     <silent><buffer>       <plug>(vimtex-env-surround-line)
        \ <plug>(vimtex-env-surround-operator)_
  xnoremap <silent><buffer>       <plug>(vimtex-env-surround-visual)
        \ :<c-u>call vimtex#env#surround_opfunc('visual')<cr>
endfunction

" }}}1

function! vimtex#env#get_surrounding(type) abort " {{{1
  " Get surrounding environment delimiters.
  "
  " This works similar to vimtex#delim#get_surrounding, except specialized for
  " environments. For normal environments it is equivalent to
  " vimtex#delim#get_surrounding('env_tex'). For math environments it combines
  " the 'env_math' delimiter type with normal known math environments.

  if a:type ==# 'normal'
    return vimtex#delim#get_surrounding('env_tex')
  endif

  if a:type !=# 'math'
    call vimtex#log#error('Wrong argument!')
    return [{}, {}]
  endif

  " First check for special math env delimiters
  let [l:open, l:close] = vimtex#delim#get_surrounding('env_math')
  if !empty(l:open) | return [l:open, l:close] | endif

  " Next check for standard math environments (only works for 1 level depth)
  let [l:open, l:close] = vimtex#delim#get_surrounding('env_tex')
  if !empty(l:open) &&
        \ index(s:math_envs, substitute(l:open.name, '\*$', '', '')) >= 0
    return [l:open, l:close]
  endif

  return [{}, {}]
endfunction

let s:math_envs = [
      \ 'align',
      \ 'alignat',
      \ 'displaymath',
      \ 'eqnarray',
      \ 'equation',
      \ 'flalign',
      \ 'gather',
      \ 'math',
      \ 'mathpar',
      \ 'multline',
      \ 'xalignat',
      \ 'xxalignat',
      \]

" }}}1

function! vimtex#env#get_inner() abort " {{{1
  let [l:open, l:close] = vimtex#env#get_surrounding('normal')

  return empty(l:open) || l:open.name ==# 'document'
        \ ? {}
        \ : {'name': l:open.name, 'open': l:open, 'close': l:close}
endfunction

" }}}1
function! vimtex#env#get_outer() abort " {{{1
  let l:save_pos = vimtex#pos#get_cursor()
  let l:current = {}

  while v:true
    let l:env = vimtex#env#get_inner()
    if empty(l:env)
      call vimtex#pos#set_cursor(l:save_pos)
      return l:current
    endif

    let l:current = l:env
    call vimtex#pos#set_cursor(vimtex#pos#prev(l:env.open))
  endwhile
endfunction

" }}}1
function! vimtex#env#get_all() abort " {{{1
  let l:save_pos = vimtex#pos#get_cursor()
  let l:stack = []

  while v:true
    let l:env = vimtex#env#get_inner()
    if empty(l:env)
      call vimtex#pos#set_cursor(l:save_pos)
      return l:stack
    endif

    call add(l:stack, l:env)
    call vimtex#pos#set_cursor(vimtex#pos#prev(l:env.open))
  endwhile
endfunction

" }}}1

function! vimtex#env#change_surrounding(type, new) abort " {{{1
  let [l:open, l:close] = vimtex#env#get_surrounding(a:type)
  if empty(l:open) | return | endif

  return vimtex#env#change(l:open, l:close, a:new)
endfunction

function! vimtex#env#change(open, close, new) abort " {{{1
  let l:new = get({
        \ '$': ['$', '$'],
        \ '\(': ['\\(', '\\)'],
        \ '$$': ['$$', '$$'],
        \ '\[': ['\[', '\]'],
        \}, a:new, ['\begin{' . a:new . '}', '\end{' . a:new . '}'])

  " execute printf("l:new is: ".l:new)
  " echo l:new
  if index(['$', '\('], a:new) >= 0
    return vimtex#env#change_to_inline_math(a:open, a:close, l:new)
  endif

  return index(['$', '\('], a:open.match) >= 0
        \ ? vimtex#env#change_to_indented(a:open, a:close, l:new)
        \ : vimtex#env#change_in_place(a:open, a:close, l:new)
endfunction

function! vimtex#env#change_to_inline_math(open, close, new) abort " {{{1
  let [l:before, l:after] = s:get_line_split(a:close)
  let l:end_with_dot = -1
  if l:before . l:after =~# '^\s*$'
    let l:curr_line = getline(a:close.lnum-1)
    if l:curr_line =~# '\.\s*$'
        let l:end_with_dot=1
    endif
    let l:line = substitute(getline(a:close.lnum - 1), '\.\s*$', a:new[1], '')
    echo "lline1" l:line
    if l:end_with_dot == 1
        let l:line=l:line."."
    endif
    call setline(a:close.lnum - 1, l:line)
    execute a:close.lnum . 'delete _'
    if !empty(trim(getline(a:close.lnum)))
      execute (a:close.lnum - 1) . 'join'
    endif
  elseif l:before =~# '^\s*$'
    let l:curr_line = getline(a:close.lnum-1)
    if l:curr_line =~# '\.\s*$'
        let l:end_with_dot=1
    endif
    let l:line = substitute(getline(a:close.lnum - 1), '\.\s*$', a:new[1], '')
    echo "lline2" l:line
    if l:end_with_dot == 1
        let l:line=l:line."."
    endif
    let l:line .= substitute(l:after, '^\s*', ' ', '')
    call setline(a:close.lnum - 1, l:line)
    execute a:close.lnum . 'delete _'
  else
    " echo "curr3" getline(a:close.lnum-1)
    " let l:line = substitute(l:before, '\s*$', a:new[1], '') . l:after
    let l:line = substitute(l:before, '\s*\(\.\)\s*$', a:new[1].'\1', '') . l:after
    echo "lline3" l:line
    call setline(a:close.lnum, l:line)
  endif

  let [l:before, l:after] = s:get_line_split(a:open)
  if l:before . l:after =~# '^\s*$'
    execute a:open.lnum . 'delete _'
    let l:after = substitute(getline(a:open.lnum), '^\s*', a:new[0], '')
    let l:prev_line = getline(a:open.lnum - 1)
    if l:prev_line =~# '^\s*$'
      call setline(a:open.lnum, matchstr(l:before, '^\s*') . l:after)
      call vimtex#pos#set_cursor([a:open.lnum, a:open.cnum])
    else
      let l:before = substitute(l:prev_line, '\s*$', ' ', '')
      call setline(a:open.lnum - 1, l:before . l:after)
      execute a:open.lnum . 'delete _'
      call vimtex#pos#set_cursor([a:open.lnum - 1, strlen(l:before)+1])
    endif
  elseif l:after =~# '^\s*$'
    let l:line = l:before
    let l:line .= substitute(getline(a:open.lnum + 1), '^\s*', a:new[0], '')
    call setline(a:open.lnum, l:line)
    execute (a:open.lnum + 1) . 'delete _'
    call vimtex#pos#set_cursor([a:open.lnum, a:open.cnum])
  else
    let l:line = l:before
    let l:line .= substitute(l:after, '^\s*', a:new[0], '')
    call setline(a:open.lnum, l:line)
    call vimtex#pos#set_cursor([a:open.lnum, a:open.cnum])
  endif
endfunction

function! vimtex#env#change_to_indented(open, close, new) abort " {{{1
  let l:cursor = vimtex#pos#get_cursor()
  let l:nlines = a:close.lnum - a:open.lnum - 1 + 3

  " Adjust cursor column position (1)
  if l:cursor[1] == a:open.lnum
    let l:cursor[2] -= a:open.cnum - indent(a:open.lnum) - &shiftwidth
  else
    " Must be adjusted after indents are applied
    let l:cur_indent = indent(l:cursor[1])
  endif

  let [l:before, l:after] = s:get_line_split(a:close)

  " echo "---l:before" l:before
  let l:before = substitute(l:before, '\s*$', '', '')
  let l:after = substitute(l:after, '^\s*', '', '')
  let l:after_firstcn = -1
  let l:after_firstc = ""

  if !empty(l:after)
    let l:after_firstcn = match(l:after, '\S')
    let l:after_firstc = l:after[l:after_firstcn]
    if l:after_firstc == "."
        let l:after=substitute(l:after, '\s*\.', '', '')
    endif
  endif

  if !empty(l:before)
    if l:after_firstc == "."
        let l:before = l:before."."
    endif
    call setline(a:close.lnum, l:before)
    call append(a:close.lnum, a:new[1])
  else
    call setline(a:close.lnum, a:new[1])
  endif
  if !empty(l:after)
    let l:after_firstcn = match(l:after, '\S')
    let l:after_firstc = l:after[l:after_firstcn]
    if l:after_firstc == "."
        let l:after=substitute(l:after, '\s*\.*', '', '')
    endif
    call append(a:close.lnum + !empty(l:before), l:after)
    let l:nlines += 1
  endif

  let [l:before, l:after] = s:get_line_split(a:open)
  let l:before = substitute(l:before, '\s*$', '', '')
  let l:after = substitute(l:after, '^\s*', '', '')
  " echo "l:before"
  " echo l:before
  " echo "a:new" a:new[0]
  if !empty(l:before)
    call setline(a:open.lnum, l:before)
    call append(a:open.lnum, a:new[0])
    call vimtex#pos#set_cursor(a:open.lnum+1, 1)
    let l:cursor[1] += 1
  else
    call setline(a:open.lnum, a:new[0])
    call vimtex#pos#set_cursor(a:open.lnum, 1)
  endif
  if !empty(l:after)
    call append(a:open.lnum + !empty(l:before), l:after)
    let l:cursor[1] += 1
  endif

  " Indent the lines
  silent execute printf('normal! =%dj', l:nlines)

  " Adjust cursor column position (2)
  if exists('l:cur_indent')
    let l:cursor[2] -= l:cur_indent - indent(l:cursor[1])
  endif

  call vimtex#pos#set_cursor(l:cursor)
endfunction

" }}}1
function! vimtex#env#change_in_place(open, close, new) abort " {{{1
  let [l:before, l:after] = s:get_line_split(a:close)
  call setline(a:close.lnum, l:before . a:new[1] . l:after)

  let [l:before, l:after] = s:get_line_split(a:open)
  call setline(a:open.lnum, l:before . a:new[0] . l:after)

  if a:open.lnum == a:close.lnum
    let l:pos = vimtex#pos#get_cursor()
    if l:pos[2] > a:open.cnum + len(a:open.match) - 1
      let l:pos[2] += len(a:new[0]) - len(a:open.match)
      call vimtex#pos#set_cursor(l:pos)
    endif
  endif
endfunction

" }}}1

function! vimtex#env#surround(l1, l2, name) abort " {{{1
  if a:l1 < 1 || a:l2 < a:l1 || empty(a:name)
    return
  endif

  let l:pos = vimtex#pos#get_cursor()
  let l:pos[1] += l:pos[1] > a:l2
  let l:pos[1] += l:pos[1] >= a:l1

  call append(a:l2, printf('\end{%s}', a:name))
  call append(a:l1-1, printf('\begin{%s}', a:name))

  silent execute printf("normal! %dG%d==", a:l1, a:l2 - a:l1 + 3)

  call vimtex#pos#set_cursor(l:pos)
endfunction

" }}}1
function! vimtex#env#surround_opfunc(type) abort " {{{1
  if a:type ==# 'operator'
    set opfunc=vimtex#env#surround_opfunc
    return 'g@'
  elseif a:type ==# 'visual'
    let l:lnum1 = getpos("'<")[1]
    let l:lnum2 = getpos("'>")[1]
  else
    let l:lnum1 = getpos("'[")[1]
    let l:lnum2 = getpos("']")[1]
  endif

  let l:name = vimtex#ui#input({
        \ 'prompt': 'Surround with environment: ',
        \})

  call vimtex#env#surround(l:lnum1, l:lnum2, l:name)
  normal! zv
endfunction

" }}}1

function! vimtex#env#delete(type) abort " {{{1
  let [l:open, l:close] = vimtex#env#get_surrounding(a:type)
  if empty(l:open) | return | endif

  if a:type ==# 'normal'
    call vimtex#cmd#delete_all(l:close)
    call vimtex#cmd#delete_all(l:open)
  else
    call l:close.remove()
    call l:open.remove()
  endif

  if getline(l:close.lnum) =~# '^\s*$'
    execute l:close.lnum . 'd _'
  endif

  if getline(l:open.lnum) =~# '^\s*$'
    execute l:open.lnum . 'd _'
  endif
endfunction

function! vimtex#env#toggle_star() abort " {{{1
  let [l:open, l:close] = vimtex#env#get_surrounding('normal')
  if empty(l:open)
        \ || l:open.name ==# 'document' | return | endif

  call vimtex#env#change(l:open, l:close,
        \ l:open.starred ? l:open.name : l:open.name . '*')
endfunction

" }}}1
function! vimtex#env#toggle_math() abort " {{{1
  let [l:open, l:close] = vimtex#env#get_surrounding('math')
  if empty(l:open) | return | endif

  let l:current = get(l:open, 'name', l:open.match)
  let l:target = get(g:vimtex_env_toggle_math_map, l:current, '$')

  call vimtex#env#change(l:open, l:close, l:target)
endfunction

" }}}1

function! vimtex#env#is_inside(env) abort " {{{1
  let l:re_start = '\\begin\s*{' . a:env . '\*\?}'
  let l:re_end = '\\end\s*{' . a:env . '\*\?}'
  try
    return searchpairpos(l:re_start, '', l:re_end, 'bnW', '', 0, 100)
  catch /E118/
    let l:stopline = max([line('.') - 500, 1])
    return searchpairpos(l:re_start, '', l:re_end, 'bnW', '', l:stopline)
  endtry
endfunction

" }}}1
function! vimtex#env#input_complete(lead, cmdline, pos) abort " {{{1
  let l:cands = map(vimtex#complete#complete('env', '', '\begin'), 'v:val.word')

  " Never include document and remove current env (place it first)
  call filter(l:cands, { _, x -> index(['document', s:env_name], v:val) < 0 })

  " Always include current env and displaymath
  let l:cands = [s:env_name] + l:cands + ['\[']

  return filter(l:cands, {_, x -> x =~# '^' . a:lead})
endfunction

" }}}1

function! s:get_line_split(delim) abort " {{{1
  let l:line = getline(a:delim.lnum)

  let l:before = strpart(l:line, 0, a:delim.cnum - 1)
  let l:after = strpart(l:line, a:delim.cnum + len(a:delim.match) - 1)

  return [l:before, l:after]
endfunction

" }}}1

function! s:operator_setup(operator, type) abort " {{{1
  let &opfunc = s:snr() . 'operator_function'

  let s:operator_abort = 0
  let s:operator = a:operator
  let s:operator_type = a:type

  " Ask for user input if necessary/relevant
  if s:operator ==# 'change'
    let l:new_env = s:change_prompt(s:operator_type)
    if empty(l:new_env)
      let s:operator_abort = 1
      return
    endif

    let s:operator_name = l:new_env
  endif
endfunction

" }}}1
function! s:operator_function(_) abort " {{{1
  if get(s:, 'operator_abort', 0) | return | endif

  let l:type = get(s:, 'operator_type', '')
  let l:name = get(s:, 'operator_name', '')

  execute 'call vimtex#env#' . {
        \   'change': 'change_surrounding(l:type, l:name)',
        \   'delete': 'delete(l:type)',
        \   'toggle_star': 'toggle_star()',
        \   'toggle_math': 'toggle_math()',
        \ }[s:operator]
endfunction

" }}}1

function! s:change_prompt(type) abort " {{{1
  let [l:open, l:close] = vimtex#env#get_surrounding(a:type)
  let g:open=l:open
  if empty(l:open) | return | endif

  let l:open_match=matchaddpos('Search',[[l:open.lnum, l:open.cnum, l:open.cnum+strlen(l:open.match)]])
  let l:close_match=matchaddpos('Search',[[l:close.lnum, l:close.cnum, l:close.cnum+strlen(l:close.match)]])
  redraw
  let l:ret=""
  if g:vimtex_env_change_autofill
    let l:name = get(l:open, 'name', l:open.match)
    let s:env_name = l:name
	echo l:name
    let l:ret=vimtex#ui#input({
          \ 'prompt': '<'.l:name.'> is changed to:',
          \ 'default': l:name,
          \ 'completion': 'customlist,vimtex#env#input_complete',
          \})
  else
    let l:name = get(l:open, 'name', l:open.is_open
          \ ? l:open.match . ' ... ' . l:open.corr
          \ : l:open.match . ' ... ' . l:open.corr)
    let s:env_name = l:name
    let l:ret=vimtex#ui#input({
          \ 'info':
          \   ['Change surrounding environment: ', ['VimtexWarning', "current env: ".l:name]],
          \ 'completion': 'customlist,vimtex#env#input_complete',
		  \ 'user_defined_prompt':"当前环境 ".l:name.", 将被修改为:",
          \})
  endif
  call matchdelete(l:open_match)
  call matchdelete(l:close_match)
  return l:ret
endfunction

" }}}1

function! s:snr() abort " {{{1
  return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction

" }}}1
