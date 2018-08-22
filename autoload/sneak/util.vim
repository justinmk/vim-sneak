if v:version >= 703
  func! sneak#util#strlen(s) abort
    return strwidth(a:s)
    "return call('strdisplaywidth', a:000)
  endf
else
  func! sneak#util#strlen(s) abort
    return strlen(substitute(a:s, ".", "x", "g"))
  endf
endif

func! sneak#util#isvisualop(op) abort
  return a:op =~# "^[vV\<C-v>]"
endf

func! sneak#util#getc() abort
  let c = getchar()
  return type(c) == type(0) ? nr2char(c) : c
endf

func! sneak#util#getchar() abort
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
func! sneak#util#has_upper(s) abort
 return -1 != match(a:s, '\C[[:upper:]]')
endf

"displays a message that will dissipate at the next opportunity.
func! sneak#util#echo(msg) abort
  redraw | echo a:msg
  augroup sneak_echo
    autocmd!
    autocmd CursorMoved,InsertEnter,WinLeave,BufLeave * redraw | echo '' | autocmd! sneak_echo
  augroup END
endf

"returns the least possible 'wincol'
"  - if 'sign' column is displayed, the least 'wincol' is 3
"  - there is (apparently) no clean way to detect if 'sign' column is visible
func! sneak#util#wincol1() abort
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
func! sneak#util#skipfold(current_line, reverse) abort
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

" Moves the cursor 1 char to the left or right; wraps at EOL, but _not_ EOF.
func! sneak#util#nudge(right) abort
  let nextchar = searchpos('\_.', 'nW'.(a:right ? '' : 'b'))
  if [0, 0] == nextchar
    return 0
  endif
  call cursor(nextchar)
  return 1
endf

" Removes highlighting.
func! sneak#util#removehl() abort
  silent! call matchdelete(w:sneak_hl_id)
  silent! call matchdelete(w:sneak_sc_hl)
endf

" Gets the 'links to' value of the specified highlight group, if any.
func! sneak#util#links_to(hlgroup) abort
  redir => hl | exec 'silent highlight '.a:hlgroup | redir END
  let s = substitute(matchstr(hl, 'links to \zs.*'), '\s', '', 'g')
  return empty(s) ? 'NONE' : s
endf

func! s:default_color(hlgroup, what, mode) abort
  let c = synIDattr(synIDtrans(hlID(a:hlgroup)), a:what, a:mode)
  return !empty(c) && c != -1 ? c : (a:what ==# 'bg' ? 'magenta' : 'white')
endfunc

func! s:init_hl() abort
  exec "highlight default Sneak guifg=white guibg=magenta ctermfg=white ctermbg=".(&t_Co < 256 ? "magenta" : "201")

  if &background ==# 'dark'
    highlight default SneakScope guifg=black guibg=white ctermfg=0     ctermbg=255
  else
    highlight default SneakScope guifg=white guibg=black ctermfg=255   ctermbg=0
  endif

  let guibg   = s:default_color('Sneak', 'bg', 'gui')
  let guifg   = s:default_color('Sneak', 'fg', 'gui')
  let ctermbg = s:default_color('Sneak', 'bg', 'cterm')
  let ctermfg = s:default_color('Sneak', 'fg', 'cterm')
  exec 'highlight default SneakLabel gui=bold cterm=bold guifg='.guifg.' guibg='.guibg.' ctermfg='.ctermfg.' ctermbg='.ctermbg

  let guibg   = s:default_color('SneakLabel', 'bg', 'gui')
  let ctermbg = s:default_color('SneakLabel', 'bg', 'cterm')
  " fg same as bg
  exec 'highlight default SneakLabelMask guifg='.guibg.' guibg='.guibg.' ctermfg='.ctermbg.' ctermbg='.ctermbg
endf

augroup sneak_colorscheme  " Re-init on :colorscheme change at runtime. #108
  autocmd!
  autocmd ColorScheme * call <sid>init_hl()
augroup END

call s:init_hl()
