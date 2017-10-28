sneak.vim :shoe:
================

Jump to any location specified by two characters.

Sneak is a powerful, reliable, yet minimal _motion_ plugin for Vim. It works with **multiple
lines**, **operators** (including repeat `.` and [surround]), motion-repeat
(`;` and `,`), **[keymaps]**, **visual** mode, **[multibyte]** text, and
**macros**.

Try *label-mode* for a minimalist alternative to
[EasyMotion](https://github.com/Lokaltog/vim-easymotion):

```vim
let g:sneak#label = 1
```

Usage
-----

<a href="http://imgur.com/Jke0mIJ" title="Click to see a short demo"><img src="https://raw.github.com/justinmk/vim-sneak/fluff/assets/readme_diagram.png"></a>

Sneak is invoked with `s` followed by exactly two characters:

    s{char}{char}

* Type `sab` to **move the cursor** immediately to the next instance of the text "ab".
    * Additional matches, if any, are highlighted until the cursor is moved.
* Type `;` to go to the next match (or `s` again, if `s_next` is enabled; see [`:help sneak`](doc/sneak.txt)).
* Type `3;` to skip to the third match from the current position.
* Type `ctrl-o` or ``` `` ``` to go back to the starting point.
    * This is a built-in Vim motion; Sneak adds to Vim's [jumplist](http://vimdoc.sourceforge.net/htmldoc/motion.html#jumplist)
      *only* on `s` invocation—not repeats—so you can 
      abandon a trail of `;` or `,` by a single `ctrl-o` or ``` `` ```.
* Type `s<Enter>` at any time to repeat the last Sneak-search.
* Type `S` to search backwards.

Sneak can be limited to a **vertical scope** by prefixing `s` with a [count].

* Type `5sxy` to go immediately to the next instance of "xy" within 5 columns
  of the cursor.

Sneak is invoked with [**operators**](http://vimdoc.sourceforge.net/htmldoc/motion.html#operator)
via `z` (because `s` is taken by surround.vim).

* Type `3dzqt` to delete up to the *third* instance of "qt".
    * Type `.` to repeat the `3dzqt` operation.
    * Type `2.` to repeat twice.
    * Type `d;` to delete up to the next match.
    * Type `4d;` to delete up to the *fourth* next match.
* Type `ysz))]` to surround in brackets up to `))`.
    * Type `;` to go to the next `))`.
* Type `gUz\}` to upper-case the text from the cursor until the next instance
  of the literal text `\}`
    * Type `.` to repeat the `gUz\}` operation.

Install
-------

- [vim-plug](https://github.com/junegunn/vim-plug)
  - `Plug 'justinmk/vim-sneak'`
- [Pathogen](https://github.com/tpope/vim-pathogen)
  - `git clone git://github.com/justinmk/vim-sneak.git ~/.vim/bundle/vim-sneak`
- Manual installation:
  - Copy the files to your `.vim` directory.

To repeat Sneak *operations* (like `dzab`) with dot `.`,
[repeat.vim](https://github.com/tpope/vim-repeat) is required.

FAQ
---

#### Why not use `/`?

For the same reason that Vim has [motions](http://vimdoc.sourceforge.net/htmldoc/motion.html#left-right-motions)
like `f` and `t`: common operations should use the fewest keystrokes.

* `/ab<cr>` requires 33% more keystrokes than `sab`
* Sets *only* the initial position in the Vim jumplist—so you can explore a
  trail of matches via `;`, then return to the start with a single `ctrl-o` or ``` `` ```
* Doesn't clutter your search history
* Input is always literal (don't need to escape special characters)
  * Ignores accents ("equivalence class") when matching
    ([#183](https://github.com/justinmk/vim-sneak/issues/183))
* Smarter, subtler highlighting

#### Why not use `f`?

* 50x more precise than `f` or `t`
* Moves vertically
* Highlights matches in the direction of your search

#### How dare you remap `s`?

You can specify any mapping for Sneak (see [`:help sneak`](doc/sneak.txt)).
By the way: `cl` is equivalent to `s`, and `cc` is equivalent to `S`.

#### How can I replace `f` with Sneak?

```vim
map f <Plug>Sneak_s
map F <Plug>Sneak_S
```

#### How can I replace `f` and/or `t` with *one-character* Sneak?

Sneak has `<Plug>` mappings for `f` and `t` 1-character-sneak.
These mappings do *not* invoke label-mode, even if you have it enabled.

```vim
map f <Plug>Sneak_f
map F <Plug>Sneak_F
map t <Plug>Sneak_t
map T <Plug>Sneak_T
```

Related
-------

* [Seek](https://github.com/goldfeld/vim-seek)
* [EasyMotion](https://github.com/Lokaltog/vim-easymotion)
* [smalls](https://github.com/t9md/vim-smalls)
* [improvedft](https://github.com/chrisbra/improvedft)
* [clever-f](https://github.com/rhysd/clever-f.vim)
* [vim-extended-ft](https://github.com/svermeulen/vim-extended-ft)
* [Fanf,ingTastic;](https://github.com/dahu/vim-fanfingtastic)

License
-------

Copyright © Justin M. Keyes. Distributed under the MIT license.

[multibyte]: http://vimdoc.sourceforge.net/htmldoc/mbyte.html#UTF-8
[keymaps]: http://vimdoc.sourceforge.net/htmldoc/mbyte.html#mbyte-keymap
[surround]: https://github.com/tpope/vim-surround
[count]: http://vimdoc.sourceforge.net/htmldoc/intro.html#[count]
