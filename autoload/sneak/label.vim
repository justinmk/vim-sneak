" NOTES:
"   problem:  cchar cannot be more than 1 character.
"   strategy: make fg/bg the same color, then conceal the other char.
" 
"   problem:  keyword highlighting always takes priority over conceal.
"   strategy: syntax clear | [do the conceal] | let &syntax=s:syntax_orig
"
" PROFILING:
"   - the search should be 'warm' before profiling
"   - searchpos() appears to be about 30% faster than 'norm! n'
"
" FEATURES:
"   - skips folds
"   - if no visible matches, does not invoke label-mode
"   - there is no 'grouping'
"     - this minimizes the steps for the common case
"     - If your search has >56 matches, press <tab> to jump to the 57th match
"       and label the next 56 matches.
" 
" cf. EASYMOTION:
"   - EasyMotion's 'single line' feature is superfluous because label-mode
"     isn't activated unless there are >=2 on-screen matches, and any key that
"     isn't a target falls through to Vim.
"   - because sneak targets 2 chars, there is never a problem discerning
"     target labels. https://github.com/Lokaltog/vim-easymotion/pull/47#issuecomment-10919205
"   - https://github.com/Lokaltog/vim-easymotion/issues/59#issuecomment-23226131
"     - easymotion edits the buffer, plans to create a new buffer
"     - 'the current way of highligthing is insanely slow'
"   - sneak handles long lines https://github.com/Lokaltog/vim-easymotion/issues/82
"   - sneak can find and highlight concealed characters

let g:sneak#target_labels = get(g:, 'sneak#target_labels', "asdfghjkl;qwertyuiopzxcvbnm/ASDFGHJKL:QWERTYUIOPZXCVBNM?")

func! s:placematch(c, pos)
  let s:matchmap[a:c] = a:pos
  exec "syntax match SneakLabel '\\%".a:pos[0]."l\\%".a:pos[1]."c.' conceal cchar=".a:c
endf

func! sneak#label#to(s, v, reverse)
  let seq = ""
  while 1
    let choice = s:do_label(a:s, a:v, a:reverse)
    let seq .= choice
    if choice != "\<Tab>" | return seq | endif
  endwhile
endf

func! s:do_label(s, v, reverse) "{{{
  let w = winsaveview()
  call s:before()
  let search_pattern = (a:s.prefix).(a:s.search).(a:s.get_onscreen_searchpattern(w))

  let i = 0
  let overflow = [0, 0] "position of the next match (if any) after we have run out of target labels.
  while 1
    " searchpos() is faster than 'norm! /'
    let p = searchpos(search_pattern, a:s.search_options_no_s, a:s.get_stopline())
    let skippedfold = sneak#util#skipfold(p[0], a:reverse) "Note: 'set foldopen-=search' does not affect search().

    if 0 == p[0] || -1 == skippedfold
      break
    elseif 1 == skippedfold
      continue
    endif

    if i < s:maxmarks
      "TODO: multibyte-aware substring: matchstr('asdfäöü', '.\{4\}\zs.') https://github.com/Lokaltog/vim-easymotion/issues/16#issuecomment-34595066
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

  let mappedto = maparg(choice, a:v ? 'x' : 'n')
  let mappedtoNext = (g:sneak#opt.absolute_dir && a:reverse)
        \ ? mappedto =~# '<Plug>Sneak\(_,\|Previous\)'
        \ : mappedto =~# '<Plug>Sneak\(_;\|Next\)'

  if choice == "\<Tab>" && overflow[0] > 0 "overflow => decorate next N matches
    call cursor(overflow[0], overflow[1])
  elseif (strlen(g:sneak#opt.label_esc) && choice ==# g:sneak#opt.label_esc)
        \ || -1 != index(["\<Esc>", "\<C-c>"], choice)
    return "\<Esc>" "exit label-mode.
  elseif !mappedtoNext && !has_key(s:matchmap, choice) "press _any_ invalid key to escape.
    call feedkeys(choice) "exit label-mode and fall through to Vim.
    return ""
  else "valid target was selected
    let p = mappedtoNext ? s:matchmap[strpart(g:sneak#target_labels, 0, 1)] : s:matchmap[choice]
    call cursor(p[0], p[1])
  endif

  return choice
endf "}}}

func! s:after()
  autocmd! sneak_label_cleanup
  silent! call matchdelete(w:sneak_cursor_hl)
  "remove temporary highlight links
  exec 'hi! link Conceal '.s:orig_hl_conceal
  exec 'hi! link Sneak '.s:orig_hl_sneak
  let &l:synmaxcol=s:synmaxcol_orig
  silent! let &l:foldmethod=s:fdm_orig
  silent! let &l:syntax=s:syntax_orig
  let &l:concealcursor=s:cc_orig
  let &l:conceallevel=s:cl_orig
  call s:restore_conceal_in_other_windows()
endf

func! s:disable_conceal_in_other_windows()
  for w in range(1, winnr('$'))
    if 'help' !=# getwinvar(w, '&buftype') && w != winnr()
        \ && empty(getbufvar(winbufnr(w), 'dirvish'))
      call setwinvar(w, 'sneak_orig_cl', getwinvar(w, '&conceallevel'))
      call setwinvar(w, '&conceallevel', 0)
    endif
  endfor
endf
func! s:restore_conceal_in_other_windows()
  for w in range(1, winnr('$'))
    if 'help' !=# getwinvar(w, '&buftype') && w != winnr()
        \ && empty(getbufvar(winbufnr(w), 'dirvish'))
      call setwinvar(w, '&conceallevel', getwinvar(w, 'sneak_orig_cl'))
    endif
  endfor
endf

func! s:before()
  let s:matchmap = {}

  " prevent highlighting in other windows showing the same buffer
  ownsyntax sneak_label

  " highlight the cursor location (else the cursor is not visible during getchar())
  let w:sneak_cursor_hl = matchadd("Cursor", '\%#', 11, -1)

  let s:cc_orig=&l:concealcursor | setlocal concealcursor=ncv
  let s:cl_orig=&l:conceallevel  | setlocal conceallevel=2

  if &l:foldmethod ==# 'syntax' " Avoid broken folds when we clear syntax below.
    let s:fdm_orig=&l:foldmethod | setlocal foldmethod=manual
  endif

  let s:syntax_orig=&syntax
  syntax clear
  " this is fast since we cleared syntax, and it allows sneak to work on very long wrapped lines.
  let s:synmaxcol_orig=&l:synmaxcol | setlocal synmaxcol=0

  let s:orig_hl_conceal = sneak#hl#links_to('Conceal')
  let s:orig_hl_sneak   = sneak#hl#links_to('Sneak')
  "set temporary link to our custom 'conceal' highlight
  hi! link Conceal SneakLabel
  "set temporary link to hide the sneak search targets
  hi! link Sneak SneakLabelMask

  call s:disable_conceal_in_other_windows()

  augroup sneak_label_cleanup
    autocmd!
    autocmd CursorMoved * call <sid>after()
  augroup END
endf

"returns 1 if a:key is invisible or special.
func! s:is_special_key(key)
  return -1 != index(["\<Esc>", "\<C-c>", "\<Space>", "\<CR>", "\<Tab>"], a:key)
    \ || maparg(a:key, 'n') =~# '<Plug>Sneak\(_;\|_,\|Next\|Previous\)'
    \ || (g:sneak#opt.s_next && maparg(a:key, 'n') =~# '<Plug>Sneak\(_s\|Forward\)')
endf

"we must do this because:
"  - we don't know which keys the user assigned to Sneak_;/Sneak_,
"  - we need to reserve special keys like <Esc> and <Tab>
func! sneak#label#sanitize_target_labels()
  let nrkeys = sneak#util#strlen(g:sneak#target_labels)
  let i = 0
  while i < nrkeys
    let k = strpart(g:sneak#target_labels, i, 1)
    if s:is_special_key(k) "remove the char
      let g:sneak#target_labels = substitute(g:sneak#target_labels, '\%'.(i+1).'c.', '', '')
      "move ; (or s if 'clever-s' is enabled) to the front.
      if !g:sneak#opt.absolute_dir
            \ && ((!g:sneak#opt.s_next && maparg(k, 'n') =~# '<Plug>Sneak\(_;\|Next\)')
            \     || (maparg(k, 'n') =~# '<Plug>Sneak\(_s\|Forward\)'))
        let g:sneak#target_labels = k . g:sneak#target_labels
      else
        let nrkeys -= 1
        continue
      endif
    endif
    let i += 1
  endwhile
endf

call sneak#label#sanitize_target_labels()
let s:maxmarks = sneak#util#strlen(g:sneak#target_labels)
