if v:version >= 703
  func! sneak#util#strlen(s)
    return strwidth(a:s)
  endf
else
  func! sneak#util#strlen(s)
    return strlen(substitute(a:s, ".", "x", "g"))
  endf
endif

" if v:version >= 703 "credit Tom Link: https://github.com/tomtom/tcomment_vim/compare/a5b1a36749f2f95d...48f5d46a15aaffb4#diff-e593e39d5b7b465fce98ea684adf2f6dR774
"   function! sneak#util#strdisplaywidth(...)
"     return call('strdisplaywidth', a:000)
"   endf
" else
"   function! sneak#util#strdisplaywidth(string, ...)
"     " NOTE: Col argument is ignored
"     return strlen(substitute(a:string, ".", "x", "g"))
"   endf
" endif

func! sneak#util#isvisualop(op)
  return a:op =~# "^[vV\<C-v>]"
endf

func! sneak#util#getc()
  let c = getchar()
  return type(c) == type(0) ? nr2char(c) : c
endf

func! sneak#util#getchar()
  let input = sneak#util#getc()
  if 1 != &iminsert
    return input
  endif
  "a language keymap is activated, so input must be resolved to the mapped values.
  let partial_keymap_seq = mapcheck(input, "l")
  while partial_keymap_seq !=# ""
    let full_keymap = maparg(input, "l")
    if full_keymap ==# "" && len(input) >= 3 "HACK: assume there are no keymaps longer than 3.
      return input
    elseif full_keymap ==# partial_keymap_seq
      return full_keymap
    endif
    let c = sneak#util#getc()
    if c == "\<Esc>" || c == "\<CR>"
      "if the short sequence has a valid mapping, return that.
      if !empty(full_keymap)
        return full_keymap
      endif
      return input
    endif
    let input .= c
    let partial_keymap_seq = mapcheck(input, "l")
  endwhile
  return input
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
    autocmd CursorMoved,InsertEnter,WinLeave,BufLeave * redraw | echo '' | autocmd! SneakEcho
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

"Moves the cursor 1 char to the left or right; wraps at EOL, but _not_ EOF.
func! sneak#util#nudge(right)
  let nextchar = searchpos('\_.', 'nW'.(a:right ? '' : 'b'))
  if [0, 0] == nextchar
    return 0
  endif
  call cursor(nextchar)
  return 1
endf

