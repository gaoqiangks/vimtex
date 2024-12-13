set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

set nomore

nnoremap q :qall!<cr>

silent edit $TEXFILE

let s:candidates = vimtex#test#completion('\gls{', '')
call assert_equal(len(s:candidates), 10)

call vimtex#test#finished()
