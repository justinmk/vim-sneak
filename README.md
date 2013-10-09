# sneak.vim: Vertical Motion for Vim

minimalist, well-behaved plugin that provides:
  - move to any location with `s` followed by exactly two characters
  - move anywhere, even offscreen (unlike EasyMotion)
  - jump back to the point of `s` invocation--repeated motion (;,) does not 
    add to the jump list
  - written from scratch, inspired by EasyMotion and seek.vim
  - jumps immediately to first match, unlike EasyMotion
  - gets out of your way as soon as you move the cursor
  - common case requires 3-char key sequence (EasyMotion requires 5: ,,fab)
  - repeat the motion with ; or ,
  - does not break f t F T ; ,
  - preserves the / register; does not add noise to `/` history
  - does not triggering search results highlighting
  - only shows highlights in current window
  - does not add to your jumps (use ; or , instead)
  - does not wrap
  - highlights additional matches until a key other than ; or , is pressed
  - range => restrict search column to +/- range size
  - always literal: `s\*` jumps to the literal `\*`
  - tested on massive 100k+ LOC syntax-highlighted file
  - tested with Vim 7.2.330+

If you, or one of your plugins, already maps `s` and `S` to some feature, sneak.vim 
fully supports alternative mappings. However, consider that *motion* mappings 
in Vim should absolutely be the *least friction* commands: mapping to something 
like `<leader>s` is really not recommended. Consider moving your existing `s` 
and `S` mappings to some other corner of your keyboard. 

Filling the gap: 
- sneak highlights are not as long-lived as `/` highlights; they don't persist 
  across windows or buffers, and they go away as soon as you do anything other 
  than interact with sneak. 


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
* provide "precision" option? (eg, 3 instead of the default 2)
* use `strwidth()` instead of `len()` to support non-ascii (vim-7.3 only) 
* operator-pending mode should accept registers
* `dzab` and `czab` wrap around, but probably shouldn't (for consistency with `sab`)
* `gs` (or something) should visual select the scoped area
* netrw mapping
* add to VAM pool https://github.com/MarcWeber/vim-addon-manager
* move to autoload/

## Known Issues
* repeat-next does not work in visual-mode



[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/justinmk/vim-sneak/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

