" TODO:
"   janus
"   YADR https://github.com/skwp/dotfiles
"
" KNOWN ISSUES:
"   sneak basic mode has no known flaws with multibyte, but
"   streak-mode target labeling is broken with multibyte
" 
" YADR easymotion settings:
"   https://github.com/skwp/dotfiles/blob/master/vim/settings/easymotion.vim
"
" NOTES:
"   problem:  cchar cannot be more than 1 character.
"   strategy: make fg/bg the same color, then conceal the other char.
" 
"   problem:  keyword highlighting always takes priority over conceal.
"   strategy: syntax clear | [do the conceal] | syntax enable
"
" PROFILING:
"   - the search should be 'warm' before profiling
"   - searchpos() appears to be about 30% faster than 'norm! n'
"
" FEATURES:
"   - skips folds
"   - if no visible matches, does not invoke streak-mode
"   - there is no 'grouping'
"     - this minimizes the steps for the common case
"     - If your search has >52 matches, press <tab> to jump to the 53rd match
"       and highlight the next 52 matches.
" 
" cf. EASYMOTION:
"   https://github.com/Lokaltog/vim-easymotion/issues/59#issuecomment-23226131
"     - easymotion edits the buffer, plans to create a new buffer
"     - "the current way of highligthing is insanely slow"

let g:sneak#target_labels = get(g:, 'sneak#target_labels', "asdfghjklqwertyuiopzxcvbnmASDFGHJKLQWERTYUIOPZXCVBNM")

func! s:placematch(c, pos)
  let s:matchmap[a:c] = a:pos
  "TODO: figure out why we must +1 the column...
  exec "syntax match SneakStreakTarget '.\\%".a:pos[0]."l\\%".(a:pos[1]+1)."c' conceal cchar=".a:c
endf

"TODO: may need to deal with 'offset' for getpos()/cursor() if virtualedit=all
func! sneak#streak#to(s, st)
  while s:do_streak(a:s, a:st) | endwhile
  call sneak#hl#removehl()
endf

func! s:do_streak(s, st)
  call s:before()
  let maxmarks = len(g:sneak#target_labels)
  let w = winsaveview()
  let search_pattern = (a:s.prefix).(a:s.search).(a:s.get_onscreen_searchpattern(w))

  let i = 0
  let overflow = [0, 0] "position of the next match (if any) after we have run out of target labels.
  while 1
    " searchpos() is faster than "norm! /m\<cr>", see profile.3.log
    let p = searchpos(search_pattern, a:s.search_options_no_s, a:s.get_stopline())

    if 0 == p[0]
      break
    endif

    let skippedfold = sneak#util#skipfold(p[0], a:st.reverse) "Note: 'set foldopen-=search' does not affect search().
    if -1 == skippedfold
      break
    elseif 1 == skippedfold
      continue
    endif

    if i < maxmarks
      let c = strpart(g:sneak#target_labels, i, 1)
      call s:placematch(c, p)
    else "we have exhausted the target labels; grab the first non-labeled match.
      let overflow = p
      break
    endif

    let i += 1
  endwhile

  call winrestview(w) | redraw

  let choice = sneak#util#getchar()

  call s:after()

  if choice == "\<Tab>" && overflow[0] > 0
    call cursor(overflow[0], overflow[1])
    return 1 "overflow => decorate next N matches
  elseif -1 != index(["\<Esc>", "\<Space>", "\<CR>"], choice)
    return 0 "exit streak-mode.
  elseif maparg(choice, 'n') =~# '<Plug>SneakNext'
    call sneak#rpt(sneak#util#isvisualop(a:st.op), 1, 0)
  elseif maparg(choice, 'n') =~# '<Plug>SneakPrevious'
    call sneak#rpt(sneak#util#isvisualop(a:st.op), 1, 1)
  elseif !has_key(s:matchmap, choice) "press _any_ invalid key to escape.
    call feedkeys(choice) "exit streak-mode and fall through to Vim.
  else "valid target was selected
    let p = s:matchmap[choice]
    call cursor(p[0], p[1])
  endif

  return 0 "no overflow, or user canceled
endf

"returns 1 if the key does something other than jumping to a match target:
"    - escape/cancel sneak-mode (<Space>, <C-c>, <Esc>)
"    - highlight next batch of targets (<Tab>)
"    - go to next/previous match (; and , by default)
func! s:is_active_key(key)
  return "\<Esc>" == a:key
    \ || "\<C-c>" == a:key
    \ || "\<Tab>" == a:key
    \ || "\<Space>" == a:key
    \ || maparg(a:key, 'n') =~# '<Plug>Sneak\(Next\|Previous\)'
endf

func! s:after()
  silent! call matchdelete(w:sneak_cursor_hl)
  "remove temporary highlight links
  if !empty(s:orig_hl_conceal) | exec 'hi! link Conceal '.s:orig_hl_conceal | else | hi! link Conceal NONE | endif
  if !empty(s:orig_hl_sneaktarget) | exec 'hi! link SneakPluginTarget '.s:orig_hl_sneaktarget | else | hi! link SneakPluginTarget NONE | endif
  let &syntax=s:syntax_orig
endf

func! s:before()
  let s:matchmap = {}

  " highlight the cursor location (else the cursor is not visible during getchar())
  let w:sneak_cursor_hl = matchadd("SneakStreakCursor", '\%#', 2, -1)

  set concealcursor=ncv
  set conceallevel=2

  let s:syntax_orig=&syntax
  setlocal syntax=OFF

  let s:orig_hl_conceal = sneak#hl#links_to('Conceal')
  let s:orig_hl_sneaktarget = sneak#hl#links_to('SneakPluginTarget')
  "set temporary link to our custom 'conceal' highlight
  hi! link Conceal SneakStreakTarget
  "set temporary link to hide the sneak search targets
  hi! link SneakPluginTarget SneakStreakMask
endf

"we must do this because:
"  - we don't know which keys the user assigned to SneakNext/Previous
"  - we need to reserve special keys like <Esc> and <Tab>
func! sneak#streak#sanitize_target_labels()
  let nrkeys = len(g:sneak#target_labels)
  let i = 0
  while i < nrkeys
    if s:is_active_key(strpart(g:sneak#target_labels, i, 1))
      "remove the char at index i
      let g:sneak#target_labels = substitute(g:sneak#target_labels, '\%'.(i+1).'c.', '', '')
      let nrkeys -= 1
    else
      let i += 1
    endif
  endwhile
endf

func! sneak#streak#init()
  call sneak#streak#sanitize_target_labels()
endf

call sneak#streak#init()
