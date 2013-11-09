
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
"   "define two new syntax conceal groups Foo2 and Foo3
"   syntax match Foo2 "e" conceal cchar=E
"   syntax match Foo3 "a" conceal cchar=A
"   "clear Foo2 syntax group, but not Foo3
"   syntax clear Foo2
"
"   "conceal match 'e' on line 18 between columns 10,60
"   syntax match Foo4 "e\%18l\%>10c\%<60c" conceal cchar=E

func! ProfileFoo()
  profile start profile.log
  profile func BuildFoo*
  autocmd VimLeavePre * profile pause
endf

func! FooHL(locations)
  syntax match Foo4 "e\%18l\%>10c\%<60c" conceal cchar=E

endf

"TODO: <space> should skip to the 53rd match, if any
let g:fooprefixes = "asdfghjklqwertyuiopzxcvbnmASDFGHJKLQWERTYUIOPZXCVBNM"
func! FooInitMap()
  let g:foomap = {}
  let nrchoices = len(g:fooprefixes)
  for i in range(0, nrchoices)
    let g:foomap[g:fooprefixes[i]]
  endfor
endf

func! PlaceMatch(c, pos)
  let g:foomap[a:c] = a:pos
  "TODO: figure out why we must +1 the column...
  exec "syntax match FooConceal '.\\%".a:pos[0]."l\\%".(a:pos[1]+1)."v' conceal cchar=".a:c
endf

"TODO: need to deal with the 'offset' returned by getpos() if virtualedit=all
"NOTE: the search should be 'warm' before profiling
"NOTE: searchpos() appears to be about 30% faster than 'norm! n' for
"      a 1-char search pattern, but needs to be tested on complicated search patterns vs 'norm! /'
func! FooMatchAndMark(s)
  for i in range(0, 200)
    " searchpos() is faster than "norm! /m\<cr>", see profile.3.log
    let p = searchpos(a:s, 'W')
    if 0 == max(p)
      break
    endif
    let c = strpart(g:fooprefixes, i, 1)
    call PlaceMatch(c, p)
  endfor
endf

func! FooInit()
  set concealcursor=ncv
  set conceallevel=2
  syntax clear
endf

