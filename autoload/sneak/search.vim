
" construct a new 'search' object
func! sneak#search#new()
  let s = {}

  func! s.init(opt, input, repeatmotion, reverse)
    let self._reverse = a:reverse
    " search pattern modifiers (case-sensitivity, magic)
    let self.prefix = sneak#search#get_cs(a:input, a:opt.use_ic_scs).'\V'
    " the escaped user input to search for
    let self.search = escape(a:input, '"\')
    " example: highlight string 'ab' after line 42, column 5 
    "          matchadd('foo', 'ab\%>42l\%5c', 1)
    let self.match_pattern = ''
    " do not wrap
    let self._search_options = 'W'
    " search backwards
    if a:reverse | let self._search_options .= 'b' | endif
    let self.search_options_no_s = self._search_options
    " save the jump on the initial invocation, _not_ repeats.
    if !a:repeatmotion | let self._search_options .= 's' | endif
  endf

  func! s._dosearch(...)
    let searchoptions = (a:0 > 0) ? a:1 : self._search_options
    let stopline = (a:0 > 1) ? a:2 : 0
    return searchpos((self.prefix).(self.match_pattern).'\zs'.(self.search)
          \, searchoptions
          \, stopline
          \)
  endf

  func! s.dosearch()
    return self._dosearch()
  endf

  func! s.get_onscreen_searchpattern(w)
    let wincol_lhs = a:w.leftcol "this is actually just to the _left_ of the first onscreen column.
    let wincol_rhs  = 2 + (winwidth(0) - sneak#util#wincol1()) + wincol_lhs
    "restrict search to window
    return '\%>'.(wincol_lhs).'c'.'\%<'.wincol_rhs.'c'
  endf

  func! s.get_stopline()
    return self._reverse ? line("w0") : line("w$")
  endf

  " returns 1 if there are n visible matches in the direction of the current search.
  func! s.hasmatches(n)
    let stopline = self._reverse ? line("w0") : line("w$")
    for i in range(1, a:n)
      " 'n' search option means 'do not move cursor'.
      let matchpos = self._dosearch('n', stopline)
      if 0 != max(matchpos) && a:n == i
        return 1
      endif
    endfor
    return 0
  endf

  return s
endf

" gets the case sensitivity modifier for the search
func! sneak#search#get_cs(input, use_ic_scs)
  if !a:use_ic_scs || !&ignorecase || (&smartcase && sneak#util#has_upper(a:input))
    return '\C'
  endif
  return '\c'
endf

"search object singleton
let g:sneak#search#instance = sneak#search#new()
