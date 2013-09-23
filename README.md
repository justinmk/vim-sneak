# sneak.vim: Vertical Motion for Vim

minimalist, well-behaved plugin that provides:
  - move to any location with `s` followed by exactly two characters
  - repeat the motion with ; or ,
  - does not break f t ; ,
  - preserves the / register; does not add noise to `/` history
  - does not triggering search results highlighting
  - only shows highlights in current window
  - does not add to your jumps (use ; or , instead)
  - does not wrap
  - highlights additional matches until a key other than ; or , is pressed
  - range => restrict search column to +/- range size
  - always literal: `s\*` jumps to the literal `\*`
  - tested with Vim 7.2.330+

## Related
* easymotion
* seek.vim
* cleverf
* https://github.com/svermeulen/vim-extended-ft

## TODO
* provide case-insensitive option
* `n;` should skip to *nth* occurrence
* vertical scope for built-in `/`
* use `strwidth()` instead of `len()` to support non-ascii (vim-7.3 only) 
* `s` should prefer the closest match *within the viewport* (regardless of 
  direction), that is, prefer a match that does not move the screen to one that is off-screen.
* operator-pending mode should accept registers

