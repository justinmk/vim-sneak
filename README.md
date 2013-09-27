# sneak.vim: Vertical Motion for Vim

minimalist, well-behaved plugin that provides:
  - written from scratch, inspired by EasyMotion and seek.vim
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

If you, or one of your plugins, already maps `s` and `S` to some feature, sneak.vim 
fully supports alternative mappings. However, consider that *motion* mappings 
in Vim should absolutely be the *least friction* commands: mapping to something 
like `<leader>s` is really not recommended. Consider moving your existing `s` 
and `S` mappings to some other corner of your keyboard. 

## Installation

Optional: [repeat.vim](https://github.com/tpope/vim-repeat) is required to repeat operations via `.`

## Related
* easymotion
* seek.vim
* cleverf
* https://github.com/svermeulen/vim-extended-ft

## TODO
* support surround.vim motion: `ysz`
* provide case-insensitive option
* `n;` should skip to *nth* occurrence
* vertical scope for built-in `/`
* provide command to allow arbitrary-length search string?
* use `strwidth()` instead of `len()` to support non-ascii (vim-7.3 only) 
* operator-pending mode should accept registers
* ~~implement `gs` (like `gn`): `cgs`~~ (probably overreach/misfeature)
* `dzab` and `czab` wrap around, but probably shouldn't (for consistency with `sab`)

## Known Issues
* if a new `s` search does not find matches, repeating (with `;` or `\`) in the opposite direction repeats the last successful search
* cannot repeat an operation that did not find a match

