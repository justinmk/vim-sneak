
" NOTE: cchar cannot be more than 1 character.
"   strategy: make SneakPluginTarget fg/bg the same color, then conceal the
"             other char.
" 
" NOTE: syntax highlighting seems to almost always take priority over 
" conceal highlighting.
"   strategy:
"       syntax clear
"       [do the conceal]
"       syntax enable
"
" :help :syn-priority
"   In case more than one item matches at the same position, the one that was
"   defined LAST wins.  Thus you can override previously defined syntax items by
"   using an item that matches the same text.  But a keyword always goes before a
"   match or region.  And a keyword with matching case always goes before a
"   keyword with ignoring case.
"
" important options:
"   set concealcursor=ncv
"   set conceallevel=2
"
"   syntax match SneakPluginTarget "e\%20l\%>10c\%<60c" conceal cchar=E
"
"   "conceal match 'e' on line 18 between columns 10,60
"   syntax match Foo4 "e\%18l\%>10c\%<60c" conceal cchar=E

func! ProfileFoo()
  profile start profile.log
  profile func Foo*
  autocmd VimLeavePre * profile pause
endf

"TODO: <space> should skip to the 53rd match, if any
let s:matchkeys = "asdfghjklqwertyuiopzxcvbnmASDFGHJKLQWERTYUIOPZXCVBNM"
let s:matchmap = {}

func! s:placematch(c, pos)
  let s:matchmap[a:c] = a:pos
  "TODO: figure out why we must +1 the column...
  exec "syntax match FooConceal '.\\%".a:pos[0]."l\\%".(a:pos[1]+1)."v' conceal cchar=".a:c
endf

"TODO: need to deal with the 'offset' returned by getpos() if virtualedit=all
"NOTE: the search should be 'warm' before profiling
"NOTE: searchpos() appears to be about 30% faster than 'norm! n' for
"      a 1-char search pattern, but needs to be tested on complicated search patterns vs 'norm! /'
func! sneak#sprint#to(s)
  call s:init()
  let maxmarks = len(s:matchkeys) - 1
  let w = winsaveview()
  for i in range(0, maxmarks)
    " searchpos() is faster than "norm! /m\<cr>", see profile.3.log
    let p = searchpos(a:s, 'W')
    if 0 == max(p)
      break
    endif
    let c = strpart(s:matchkeys, i, 1)
    call s:placematch(c, p)
  endfor
  call winrestview(w)
  redraw
  let choice = s:getchar()
  if choice != "\<Esc>"
    let p = s:matchmap[choice]
    call setpos('.', [ 0, p[0], p[1], 0 ])
  endif
  setlocal syntax=ON
endf

func! s:getchar()
  let c = getchar()
  return type(c) == type(0) ? nr2char(c) : c
endf

func! s:init()
  set concealcursor=ncv
  set conceallevel=2
  "syntax clear
  setlocal syntax=OFF
  hi Conceal guibg=magenta guifg=white
endf

