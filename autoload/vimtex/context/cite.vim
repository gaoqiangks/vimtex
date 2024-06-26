" VimTeX - LaTeX plugin for Vim
"
" Maintainer: Karl Yngve Lervåg
" Email:      karl.yngve@gmail.com
"

function! vimtex#context#cite#new() abort " {{{1
  return deepcopy(s:handler)
endfunction

" }}}1

let s:handler = {
      \ 'name': 'citation handler',
      \}
function! s:handler.match(cmd, word) abort dict " {{{1
  let self.selected = vimtex#cite#get_key(a:cmd, a:word)
  return !empty(self.selected)
endfunction

" }}}1
function! s:handler.get_actions() abort dict " {{{1
  let l:entry = vimtex#cite#get_entry(self.selected)

  if empty(l:entry)
    call vimtex#log#warning('Cite key not found: ' .. self.selected)
    return {}
  endif

  return s:actions.create(l:entry)
endfunction

" }}}1

let s:actions = {
      \ 'menu': [
      \   {'name': 'Edit entry',
      \    'func': 'edit'},
      \   {'name': 'Show entry',
      \    'func': 'show'},
      \ ],
      \}
function! s:actions.create(entry) abort dict " {{{1
  let l:new = deepcopy(self)
  unlet l:new.create

  let l:new.entry = deepcopy(a:entry)
  let l:new.prompt = 'Context menu for citekey ' .. a:entry.key

  if has_key(a:entry, 'file')
    let l:pdfs = filter(split(a:entry.file, ';'),
          \ {_, x -> fnamemodify(x, ':e') ==? 'pdf'})
    if !empty(l:pdfs)
      let l:new.pdfs = map(l:pdfs, {_, x -> expand(x)})
      call add(l:new.menu, {'name': 'Open PDF', 'func': 'open_pdf'})
    endif
  endif

  if has_key(a:entry, 'doi')
    call add(l:new.menu, {'name': 'Open doi', 'func': 'open_doi'})
  endif

  if has_key(a:entry, 'eprint')
        \ && (a:entry.eprint[0:4] ==# 'arXiv'
        \     || (has_key(a:entry, 'archiveprefix')
        \         && a:entry.archiveprefix ==# 'arXiv'))
    call add(l:new.menu, {'name': 'Open arXiv', 'func': 'open_arxiv'})
  endif

  if has_key(a:entry, 'url')
    call add(l:new.menu, {'name': 'Open url', 'func': 'open_url'})
  endif

  if executable('zotero')
    call add(l:new.menu, {'name': 'Open in Zotero', 'func': 'open_zotero'})
  endif

  if vimtex#util#get_os() ==# 'mac'
    let l:output = vimtex#jobs#capture(
          \ 'osascript -l JavaScript -e ''Application("BibDesk").id()''')
    if join(l:output) =~# 'edu.ucsd.cs.mmccrack.bibdesk'
      call add(l:new.menu, {'name': 'Open in BibDesk', 'func': 'open_bdsk'})
    endif
  endif

  return l:new
endfunction

" }}}1
function! s:actions.show() abort dict " {{{1
  let l:entry = deepcopy(self.entry)

  call vimtex#ui#echo([
        \ ['Normal', '@'],
        \ ['VimtexMsg', l:entry.type],
        \ ['Normal', '{'],
        \ ['Special', l:entry.key],
        \ ['Normal', ','],
        \])

  for l:x in ['key', 'type', 'source_lnum', 'source_file']
    if has_key(l:entry, l:x)
      call remove(l:entry, l:x)
    endif
  endfor

  for l:x in ['title', 'author', 'year']
    if has_key(l:entry, l:x)
      call vimtex#ui#echo([
            \ ['VimtexInfoValue', '  ' .. l:x .. ': '],
            \ ['Normal', remove(l:entry, l:x)]
            \])
    endif
  endfor

  for [l:key, l:val] in items(l:entry)
      call vimtex#ui#echo([
            \ ['VimtexInfoValue', '  ' .. l:key .. ': '],
            \ ['Normal', l:val]
            \])
  endfor
  call vimtex#ui#echo([['Normal', '}']])
endfunction

" }}}1
function! s:actions.edit() abort dict " {{{1
  execute 'edit' self.entry.source_file
  filetype detect

  call vimtex#pos#set_cursor(self.entry.source_lnum, 0)
  normal! zv
endfunction

" }}}1
function! s:actions.open_pdf() abort dict " {{{1
  let l:readable = filter(self.pdfs, {_, x -> filereadable(x)})
  if empty(l:readable)
    call vimtex#log#warning('Could not open PDF file!')
    for l:file in self.pdfs
      call vimtex#log#info('Filename: ' .. l:file)
    endfor
    return
  endif

  let l:file = vimtex#ui#select(l:readable, {
        \ 'prompt': 'Open file:',
        \})
  if empty(l:file) | return | endif

  call vimtex#jobs#start(
        \ g:vimtex_context_pdf_viewer
        \ .. ' ' .. vimtex#util#shellescape(l:file),
        \ {'detached': v:true})
endfunction

" }}}1
function! s:actions.open_arxiv() abort dict " {{{1
  let l:id = matchstr(self.entry.eprint, '\v^(arXiv:)?\zs.*')
  call vimtex#util#www('https://arxiv.org/abs/' .. l:id)
endfunction

" }}}1
function! s:actions.open_doi() abort dict " {{{1
  call vimtex#util#www('http://dx.doi.org/' .. self.entry.doi)
endfunction

" }}}1
function! s:actions.open_url() abort dict " {{{1
  call vimtex#util#www(self.entry.url)
endfunction

" }}}1
function! s:actions.open_zotero() abort dict " {{{1
  call vimtex#util#www('zotero://select/items/bbt:' .. self.entry.key)
endfunction

" }}}1
function! s:actions.open_bdsk() abort dict " {{{1
  call vimtex#util#www('x-bdsk://' .. vimtex#util#url_encode(self.entry.key))
endfunction

" }}}1
