# sneak.vim :shoe:

**Sneak** is a simple Vim plugin that fills the gap between the `f` and `/` 
motions without discarding Vim's many useful built-in motions.

### Usage (assuming default mappings)

Sneak is invoked with `s` (sneak forward) or `S` (sneak backwards), followed by exactly two 
characters:

    s{char}{char}

* Press `sab` to **move the cursor** immediately to the next instance of the text "ab".
    * Additional matches, if any, are highlighted until the cursor is moved.
* Press `;` to go to the next match.
* Press `ctrl-o` or `` to go back to the starting point.
    * This is a built-in Vim motion; Sneak adds to Vim's [jumplist](http://vimdoc.sourceforge.net/htmldoc/motion.html#jumplist)
      *only* on `s` invocation, *not* repeated matches, so you can 
      always abandon a trail of `;` or `,` by a single `ctrl-o` or ``).

Sneak can be **scoped** to a column of width 2×{number} by prefixing `s`
with a number.

* Press `5sxy` to go immediately to the next instance of the text "xy" 
  scoped to the *5 columns left and right of the cursor*. 
    * This *vertical scope* is indicated by a highlight block.

Sneak is invoked with [**operators**](http://vimdoc.sourceforge.net/htmldoc/motion.html#operator)
by using `z` (because `s` is taken by surround.vim).

* Press `dzqt` to delete the text from the cursor to the next instance of the text "qt".
    * Press `.` to repeat the `dzqt` operation.
* Press `gUz }` to upper-case the text from the cursor to the next instance of
  the text " }".
    * Press `.` to repeat the `gUz }` operation.

### Overview

Vim has a range of useful motions 
that cover general cases and special cases, but it's not always easy to move diagonally across 
several lines or horizontally across a long line. Vim's built-in `f` motion is restricted to 
the current line; and the built-in `/` search is not always appropriate for medium-distance 
motion (it also clutters your search history). Vim's built-in `H`, `M`, and `L` are great for 
bisecting a distance (you can even offset `H` and `L` with a count), but from there the cursor 
is potentially several lines and columns away from the precise target. 

Sneak covers that distance in three keystrokes:

    s{char}{char}

Sneak was inspired by [Seek](https://github.com/goldfeld/vim-seek) and 
[EasyMotion](https://github.com/Lokaltog/vim-easymotion), but it's written from scratch and uses stock 
Vim functions for its core behavior. Unlike Seek, Sneak works across **multiple lines**, 
works with **operators** (also supports **repeat** with the dot `.` command), works in **visual mode**, 
and supports **motion-repeat** via `;` and `,`. Unlike EasyMotion, Sneak *embraces* Vim's built-in 
motions: its goal is to supplement—not replace—Vim's default text navigation approach; 
and EasyMotion by default requires five (5) keystrokes to 
move to a position, while the common case for Sneak is **three (3) keystrokes**.

### Details

* Sneak chooses sane defaults out-of-the-box, but the defaults can be changed using the various 
  `<Plug>` mappings. E.g., if you would rather just replace Vim's built-in `f` completely with 
  Sneak, put this in your .vimrc: 
```
      nmap f <Plug>SneakForward
      nmap F <Plug>SneakBackward
      g:sneak#options.nextprev_f = 0 
```

* Default mappings:
    * `s` (and `S`) waits for two characters, then immediately moves to the next (previous) match. 
      Additional matches are highlighted until the cursor is moved. **Works across multiple lines.**
        * `s` works in visual mode, too (use `Z` to go backward, because `S` is taken by surround.vim).
    * `{number}s` enters *vertical scope* mode which restricts the search to 2× the column width specified by `{number}`. 
    * `;` and `,` repeat the last `s` and `S`. **They also work correctly with `f` and `t`.**
        * If your mapleader is `,` then sneak.vim maps `\` instead of `,`. You can 
          override this by specifying some other mapping: `nmap ? <Plug>SneakPrevious`
    * Use `z` for operations; for example, `dzab` deletes from the cursor to the next instance of "ab". 
      `dZab` deletes backwards to the previous instance. `czab` `cZab` `yzab` and `yZab` also work as expected.
        * **Repeat the operation** with dot `.` (requires [repeat.vim](https://github.com/tpope/vim-repeat))


If you, or one of your plugins, already maps `s` and `S` to some feature, Sneak 
provides `<Plug>` mappings for you to specify alternative key maps. Keep in mind, 
however, that *motion* mappings should absolutely be the *least friction* mappings 
in your editor, because motion is the most common editor task. Remapping Sneak to 
something like `<leader>s` is really not recommended; consider moving your existing `s` 
and `S` mappings to some other corner of your keyboard. 

### Motivation

Here's how Sneak differs from Vim's built-in `/` search and other plugins:

  - move to any location with `s` followed by exactly two characters
  - move anywhere, even offscreen (unlike EasyMotion)
  - jump back to the point of `s` invocation via `ctrl-o` or `` (backtick backtick)
    - only the *initial* invocation adds to the jumplist
        - repeat-motion via `;` or `,` does *not* add to the jumplist
  - jumps immediately to first match (unlike EasyMotion)
  - gets out of your way as soon as you move the cursor (highlights and autocmds are cleared)
  - common case requires 3-char key sequence (EasyMotion requires 5: `,,fab`)
  - repeat the motion with `;` or `,`
  - does not break expected behavior of `f t F T ; ,`
  - preserves the `/` register, does not add noise to `/` history
  - does not wrap
  - highlights additional matches until a key other than ; or , is pressed
  - *vertical scope* with `{number}s{char}{char}` restricts search column to 2× `number` size
  - always literal, for example `s\*` jumps to the literal `\*`

### Bugs

Sneak is designed to be well-behaved and bug-free. There should be no surprises except pleasant 
surprises—like "OMG, it actually works".

If you find a bug, please report it, and perhaps include the output of:

    :call sneak#debug#report()

Sneak is tested on 100k+ line syntax-highlighted file, with Vim 7.2.330, 7.3, 7.4.

### Installation

To install Sneak manually, just place the files directly in your `.vim` directory 
(`_vimfiles` on Windows).

Or, use a plugin manager:

- [Pathogen](https://github.com/tpope/vim-pathogen)
  - `cd ~/.vim/bundle && git clone git://github.com/justinmk/vim-sneak.git`
- [Vundle](https://github.com/gmarik/vundle)
  1. Add `Bundle 'justinmk/vim-sneak'` to .vimrc
  2. Run `:BundleInstall`
- [NeoBundle](https://github.com/Shougo/neobundle.vim)
  1. Add `NeoBundle 'justinmk/vim-sneak'` to .vimrc
  2. Run `:NeoBundleInstall`
- [vim-plug](https://github.com/junegunn/vim-plug)
  1. Add `Plug 'justinmk/vim-sneak'` to .vimrc
  2. Run `:PlugInstall`

If you want to be able to repeat Sneak *operations* (like `dzab`) with dot `.`,
then [repeat.vim](https://github.com/tpope/vim-repeat) is required. However, to repeat 
Sneak *motions* via `;` and `,` you don't need to install anything except Sneak.

### Related
* [Seek](https://github.com/goldfeld/vim-seek)
* [EasyMotion](https://github.com/Lokaltog/vim-easymotion)
* [clever-f](https://github.com/rhysd/clever-f.vim)
* [vim-extended-ft](https://github.com/svermeulen/vim-extended-ft)
* [Fanf,ingTastic; ](https://github.com/dahu/vim-fanfingtastic)

### TODO
* automatically handle special case if user maps SneakFoo to `f`
* operations (and repeat-operation) should take a count
* support surround.vim motion: `ysz`
* `n;` should skip to *nth* occurrence
* vertical scope for built-in `/`
* use `strwidth()` instead of `len()` to support multibyte (vim-7.3 only) 
* operator-pending mode should accept registers
* `dzab` and `czab` wrap around, but probably shouldn't (for consistency with `sab`)
* `gs` (or something) should visual select the scoped area
* netrw mapping
* add to VAM pool https://github.com/MarcWeber/vim-addon-manager
* move to autoload/

### License

Copyright © Justin M. Keyes. Distributed under the MIT license.


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/justinmk/vim-sneak/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

