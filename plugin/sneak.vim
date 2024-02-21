" sneak.vim - The missing motion
" Author:       Justin M. Keyes
" Version:      1.8
" License:      MIT

if exists('g:loaded_sneak_plugin') || &compatible || v:version < 700
  finish
endif
let g:loaded_sneak_plugin = 1

let s:cpo_save = &cpo
set cpo&vim

func! s:sneak_init() abort
  unlockvar g:sneak_opt
  "options                                 v-- for backwards-compatibility
  let g:sneak_opt = { 'f_reset' : get(g:, 'sneak#nextprev_f', get(g:, 'sneak#f_reset', 1))
      \ ,'t_reset'      : get(g:, 'sneak#nextprev_t', get(g:, 'sneak#t_reset', 1))
      \ ,'s_next'       : get(g:, 'sneak#s_next', 0)
      \ ,'absolute_dir' : get(g:, 'sneak#absolute_dir', 0)
      \ ,'use_ic_scs'   : get(g:, 'sneak#use_ic_scs', 0)
      \ ,'map_netrw'    : get(g:, 'sneak#map_netrw', 1)
      \ ,'label'        : get(g:, 'sneak#label', get(g:, 'sneak#streak', 0)) && (v:version >= 703) && has("conceal")
      \ ,'label_esc'    : get(g:, 'sneak#label_esc', get(g:, 'sneak#streak_esc', "\<space>"))
      \ ,'prompt'       : get(g:, 'sneak#prompt', '>')
      \ }

  for k in ['f', 't'] "if user mapped f/t to Sneak, then disable f/t reset.
    if maparg(k, 'n') =~# 'Sneak'
      let g:sneak_opt[k.'_reset'] = 0
    endif
  endfor
  lockvar g:sneak_opt
endf

call s:sneak_init()

" 2-char sneak
nnoremap <silent> <Plug>Sneak_s :<c-u>call sneak#wrap('', 2, 0, 2, 1)<cr>
nnoremap <silent> <Plug>Sneak_S :<c-u>call sneak#wrap('', 2, 1, 2, 1)<cr>
xnoremap <silent> <Plug>Sneak_s :<c-u>call sneak#wrap(visualmode(), 2, 0, 2, 1)<cr>
xnoremap <silent> <Plug>Sneak_S :<c-u>call sneak#wrap(visualmode(), 2, 1, 2, 1)<cr>
onoremap <silent> <Plug>Sneak_s :<c-u>call sneak#wrap(v:operator, 2, 0, 2, 1)<cr>
onoremap <silent> <Plug>Sneak_S :<c-u>call sneak#wrap(v:operator, 2, 1, 2, 1)<cr>

onoremap <silent> <Plug>SneakRepeat :<c-u>call sneak#wrap(v:operator, sneak#util#getc(), sneak#util#getc(), sneak#util#getc(), sneak#util#getc())<cr>

" repeat motion (explicit--as opposed to implicit 'clever-s')
nnoremap <silent> <Plug>Sneak_; :<c-u>call sneak#rpt('', 0)<cr>
nnoremap <silent> <Plug>Sneak_, :<c-u>call sneak#rpt('', 1)<cr>
xnoremap <silent> <Plug>Sneak_; :<c-u>call sneak#rpt(visualmode(), 0)<cr>
xnoremap <silent> <Plug>Sneak_, :<c-u>call sneak#rpt(visualmode(), 1)<cr>
onoremap <silent> <Plug>Sneak_; :<c-u>call sneak#rpt(v:operator, 0)<cr>
onoremap <silent> <Plug>Sneak_, :<c-u>call sneak#rpt(v:operator, 1)<cr>

" 1-char 'enhanced f' sneak
nnoremap <silent> <Plug>Sneak_f :<c-u>call sneak#wrap('', 1, 0, 1, 0)<cr>
nnoremap <silent> <Plug>Sneak_F :<c-u>call sneak#wrap('', 1, 1, 1, 0)<cr>
xnoremap <silent> <Plug>Sneak_f :<c-u>call sneak#wrap(visualmode(), 1, 0, 1, 0)<cr>
xnoremap <silent> <Plug>Sneak_F :<c-u>call sneak#wrap(visualmode(), 1, 1, 1, 0)<cr>
onoremap <silent> <Plug>Sneak_f :<c-u>call sneak#wrap(v:operator, 1, 0, 1, 0)<cr>
onoremap <silent> <Plug>Sneak_F :<c-u>call sneak#wrap(v:operator, 1, 1, 1, 0)<cr>

" 1-char 'enhanced t' sneak
nnoremap <silent> <Plug>Sneak_t :<c-u>call sneak#wrap('', 1, 0, 0, 0)<cr>
nnoremap <silent> <Plug>Sneak_T :<c-u>call sneak#wrap('', 1, 1, 0, 0)<cr>
xnoremap <silent> <Plug>Sneak_t :<c-u>call sneak#wrap(visualmode(), 1, 0, 0, 0)<cr>
xnoremap <silent> <Plug>Sneak_T :<c-u>call sneak#wrap(visualmode(), 1, 1, 0, 0)<cr>
onoremap <silent> <Plug>Sneak_t :<c-u>call sneak#wrap(v:operator, 1, 0, 0, 0)<cr>
onoremap <silent> <Plug>Sneak_T :<c-u>call sneak#wrap(v:operator, 1, 1, 0, 0)<cr>

nnoremap <silent> <Plug>SneakLabel_s :<c-u>call sneak#wrap('', 2, 0, 2, 2)<cr>
nnoremap <silent> <Plug>SneakLabel_S :<c-u>call sneak#wrap('', 2, 1, 2, 2)<cr>
xnoremap <silent> <Plug>SneakLabel_s :<c-u>call sneak#wrap(visualmode(), 2, 0, 2, 2)<cr>
xnoremap <silent> <Plug>SneakLabel_S :<c-u>call sneak#wrap(visualmode(), 2, 1, 2, 2)<cr>
onoremap <silent> <Plug>SneakLabel_s :<c-u>call sneak#wrap(v:operator, 2, 0, 2, 2)<cr>
onoremap <silent> <Plug>SneakLabel_S :<c-u>call sneak#wrap(v:operator, 2, 1, 2, 2)<cr>

if !hasmapto('<Plug>SneakForward') && !hasmapto('<Plug>Sneak_s', 'n') && mapcheck('s', 'n') ==# ''
  nmap s <Plug>Sneak_s
endif
if !hasmapto('<Plug>SneakBackward') && !hasmapto('<Plug>Sneak_S', 'n') && mapcheck('S', 'n') ==# ''
  nmap S <Plug>Sneak_S
endif
if !hasmapto('<Plug>Sneak_s', 'o') && mapcheck('z', 'o') ==# ''
  omap z <Plug>Sneak_s
endif
if !hasmapto('<Plug>Sneak_S', 'o') && mapcheck('Z', 'o') ==# ''
  omap Z <Plug>Sneak_S
endif

if !hasmapto('<Plug>Sneak_;', 'n') && !hasmapto('<Plug>SneakNext', 'n') && mapcheck(';', 'n') ==# ''
  nmap ; <Plug>Sneak_;
  omap ; <Plug>Sneak_;
  xmap ; <Plug>Sneak_;
endif
if !hasmapto('<Plug>Sneak_,', 'n') && !hasmapto('<Plug>SneakPrevious', 'n')
  if mapcheck(',', 'n') ==# ''
    nmap , <Plug>Sneak_,
    omap , <Plug>Sneak_,
    xmap , <Plug>Sneak_,
  elseif mapcheck('\', 'n') ==# '' || mapcheck('\', 'n') ==# ','
    nmap \ <Plug>Sneak_,
    omap \ <Plug>Sneak_,
    xmap \ <Plug>Sneak_,
  endif
endif

if !hasmapto('<Plug>VSneakForward') && !hasmapto('<Plug>Sneak_s', 'v') && mapcheck('s', 'x') ==# ''
  xmap s <Plug>Sneak_s
endif
if !hasmapto('<Plug>VSneakBackward') && !hasmapto('<Plug>Sneak_S', 'v') && mapcheck('Z', 'x') ==# ''
  xmap Z <Plug>Sneak_S
endif

" redundant legacy mappings for backwards compatibility (must come _after_ the hasmapto('<Plug>Sneak_S') checks above)
nmap <Plug>SneakForward   <Plug>Sneak_s
nmap <Plug>SneakBackward  <Plug>Sneak_S
xmap <Plug>VSneakForward  <Plug>Sneak_s
xmap <Plug>VSneakBackward <Plug>Sneak_S
xmap <Plug>VSneakNext     <Plug>Sneak_;
xmap <Plug>VSneakPrevious <Plug>Sneak_,
nmap <Plug>(SneakStreak)         <Plug>SneakLabel_s
nmap <Plug>(SneakStreakBackward) <Plug>SneakLabel_S
xmap <Plug>(SneakStreak)         <Plug>SneakLabel_s
xmap <Plug>(SneakStreakBackward) <Plug>SneakLabel_S
omap <Plug>(SneakStreak)         <Plug>SneakLabel_s
omap <Plug>(SneakStreakBackward) <Plug>SneakLabel_S
nmap <Plug>SneakNext     <Plug>Sneak_;
nmap <Plug>SneakPrevious <Plug>Sneak_,
xmap <Plug>SneakNext     <Plug>Sneak_;
xmap <Plug>SneakPrevious <Plug>Sneak_,
omap <Plug>SneakNext     <Plug>Sneak_;
omap <Plug>SneakPrevious <Plug>Sneak_,

if g:sneak_opt.map_netrw && -1 != stridx(maparg("s", "n"), "Sneak")
  func! s:map_netrw_key(key) abort
    let expanded_map = maparg(a:key,'n')
    if !strlen(expanded_map) || expanded_map =~# '_Net\|FileBeagle'
      if strlen(expanded_map) > 0 "else, mapped to <nop>
        silent exe (expanded_map =~# '<Plug>' ? 'nmap' : 'nnoremap').' <buffer> <silent> <leader>'.a:key.' '.expanded_map
      endif
      "unmap the default buffer-local mapping to allow Sneak's global mapping.
      silent! exe 'nunmap <buffer> '.a:key
    endif
  endf

  augroup sneak_netrw
    autocmd!
    autocmd FileType netrw,filebeagle autocmd sneak_netrw CursorMoved <buffer>
          \ call <sid>map_netrw_key('s') | call <sid>map_netrw_key('S') | autocmd! sneak_netrw * <buffer>
  augroup END
endif


let &cpo = s:cpo_save
unlet s:cpo_save
