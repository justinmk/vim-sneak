

func! sneak#util#getchar()
  let c = getchar()
  return type(c) == type(0) ? nr2char(c) : c
endf

"returns 1 if the string contains an uppercase char. [unicode-compatible]
func! sneak#util#has_upper(s)
 return -1 != match(a:s, '\v[[:upper:]]+')
endf
