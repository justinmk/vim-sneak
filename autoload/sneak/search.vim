
" construct a new 'search' object
func! sneak#search#new()
  let s = {}

  func! s.init(opt, input, repeatmotion, reverse)
    " search pattern modifiers (case-sensitivity, magic)
    let self.prefix = sneak#search#get_cs(a:input, a:opt.use_ic_scs).'\V'
    " the escaped user input to search for
    let self.search = escape(a:input, '"\')

    " example: highlight string 'ab' after line 42, column 5 
    "          matchadd('foo', 'ab\%>42l\%5c', 1)
    let self.match_pattern = ''

    let self._reverse = a:reverse

    " do not wrap
    let self._search_options = 'W'
    " search backwards
    if a:reverse | let self._search_options .= 'b' | endif
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

  " returns true if there are n _visible_ matches after the cursor position.
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
