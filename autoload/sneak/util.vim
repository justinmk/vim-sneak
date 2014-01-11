func! sneak#util#isvisualop(op)
  return a:op =~# "^[vV\<C-v>]"
endf

func! sneak#util#getchar()
  let c = getchar()
  return type(c) == type(0) ? nr2char(c) : c
endf

"returns 1 if the string contains an uppercase char. [unicode-compatible]
func! sneak#util#has_upper(s)
 return -1 != match(a:s, '\C[[:upper:]]')
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

"Moves the cursor to the first line after the current folded lines.
"Returns:
"     1  if the cursor was moved
"     0  if the cursor is not in a fold
"    -1  if the start/end of the fold is at/above/below the edge of the window
func! sneak#util#skipfold(current_line, reverse)
  let foldedge = a:reverse ? foldclosed(a:current_line) : foldclosedend(a:current_line)
  if -1 != foldedge
    if (a:reverse && foldedge <= line("w0")) "fold starts at/above top of window.
                \ || foldedge >= line("w$")  "fold ends at/below bottom of window.
      return -1
    endif
    call line(foldedge)
    call col(a:reverse ? 1 : '$')
    return 1
  endif
  return 0
endf

