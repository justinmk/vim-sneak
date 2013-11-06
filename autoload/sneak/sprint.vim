
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
syntax match SneakPluginTarget "e\%20l\%>10c\%<60c" conceal cchar=E


"define two new syntax conceal groups Foo2 and Foo3
syntax match Foo2 "e" conceal cchar=E
syntax match Foo3 "a" conceal cchar=A
"clear Foo2 syntax group, but not Foo3
syntax clear Foo2

"conceal match 'e' on line 18 between columns 10,60
syntax match Foo4 "e\%18l\%>10c\%<60c" conceal cchar=E

func! ProfileFoo()
  profile start profile.log
  profile func BuildFoo*
  autocmd VimLeavePre * profile pause
endf

"TODO: need to deal with the 'offset' returned by getpos() if virtualedit=all
"NOTE: the search should be 'warm' before profiling
"NOTE: searchpos() appears to be about 30% faster than 'norm! n' for
"      a 1-char search pattern, but needs to be tested on complicated search patterns vs 'norm! /'
func! BuildFoo()
  exec "norm! /m\<cr>"
  let g:foomatches = []
  let p1 = getpos(".") "first match postion
  call add(g:foomatches, p1)
  for i in range(1, 200)
    norm! n
    let p = getpos(".")
    if p1[1] == p[1] && p1[2] == p[2]
      " break
    endif
    call add(g:foomatches, p)
  endfor
endf

" faster that BuildFoo(), see profile.3.log
func! BuildFoo2()
  let g:foomatches = []
  let p1 = searchpos("m") "first match postion
  call add(g:foomatches, p1)
  for i in range(1, 200)
    let p = searchpos("m")
    if p1[0] == p[0] && p1[1] == p[1]
      " break
    endif
    call add(g:foomatches, p)
  endfor
endf
