hdevtools Vim Plugin
====================

Vim plugin for Haskell development powered by the lightnight fast
[hdevtools](<https://github.com/bitc/hdevtools/>) background server.


About
-----

[hdevtools](<https://github.com/bitc/hdevtools/>) is a command line program
powered by the GHC API, that provides services for Haskell development.
hdevtools works by running a persistent process in the background, so that your
Haskell modules remain in memory, instead of having to reload everything each
time you change only one file. This is just like `:reload` in GHCi - with
hdevtools you get the speed of GHCi as well as tight integration with your
editor.

This is the Vim plugin that integrates Vim with hdevtools.


Installation
------------

1. You must install the `hdevtools` command line program, It can be found
   here: <https://github.com/bitc/hdevtools/>, or from Hackage:

        $ cabal install hdevtools

2. Install this plugin. [pathogen.vim](<https://github.com/tpope/vim-pathogen/>)
   is the recommended way:

        cd ~/.vim/bundle
        git clone https://github.com/bitc/vim-hdevtools.git

3. Configure your keybindings in your `.vimrc` file. I recommend something
   like:

        au FileType haskell nnoremap <buffer> <F1> :HdevtoolsType<CR>
        au FileType haskell nnoremap <buffer> <silent> <F2> :HdevtoolsClear<CR>


Features
--------

### Type Checking ###

The best feature of the hdevtools command is near-instant checking of Haskell
source files for errors - it's fast even for huge projects.

This Vim plugin does not have direct support for interacting with this feature.
Instead, I recommend using the excellent
[Syntastic](<https://github.com/scrooloose/syntastic>) plugin.

### Type Information ###

Position the cursor anywhere in a Haskell source file, and execute
`HdevtoolsType` (or press the `<F1>`) key if you have configured as above).

The type for the expression under the cursor will be printed, and the
expression will be highlighted. Repeated presses will expand the expression
that is examined.

You can execute `HdevtoolsClear` to get rid of the highlighting.

Customization
-------------

You can set the `g:hdevtools_options` variable to pass custom options to
hdevtools.

This is useful for passing options through to GHC with the hdevtools `-g`
flag. For example, if your project source code is in a `src` directory,
and you want to use the GHC option `-Wall`, then stick the following somewhere
appropriate (such as your project's `Session.vim`):

    let g:hdevtools_options = '-g-isrc -g-Wall'

Make sure that each GHC option has its own `-g` prefix (don't group multiple
options like this: `"-g-isrc\ -Wall"`)


Credits
-------

Parts of the design of this plugin were inspired by
[ghcmod-vim](<https://github.com/eagletmt/ghcmod-vim/>), and large amounts of
code were also taken.
