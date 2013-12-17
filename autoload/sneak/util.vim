

func! sneak#util#getchar()
  let c = getchar()
  return type(c) == type(0) ? nr2char(c) : c
endf

"returns 1 if the string contains an uppercase char. [unicode-compatible]
func! sneak#util#has_upper(s)
 return -1 != match(a:s, '\v[[:upper:]]+')
endf

"displays a message that will dissipate at the next opportunity.
func! sneak#util#echo(msg)
  redraw | echo a:msg
  augroup SneakEcho
    autocmd!
    autocmd InsertEnter,WinLeave,BufLeave * redraw | echo '' | autocmd! SneakEcho
    autocmd CursorMoved * redraw | echo '' | autocmd! SneakEcho
  augroup END
endf

"returns the least possible 'wincol'
"  - if 'sign' column is displayed, the least 'wincol' is 3
"  - there is (apparently) no clean way to detect if 'sign' column is visible
func! sneak#util#wincol1()
  let w = winsaveview()
  norm! 0
  let c = wincol()
  call winrestview(w)
  return c
endf
