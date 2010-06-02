"    Copyright: Copyright (C) 2007-2010 Stephen Bach
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               lusty-explorer.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
"
" Name Of File: lusty-explorer.vim
"  Description: Dynamic Filesystem and Buffer Explorer Vim Plugin
"  Maintainers: Stephen Bach <this-file@sjbach.com>
"               Matt Tolton <matt-lusty-explorer@tolton.com>
" Contributors: Raimon Grau, Sergey Popov, Yuichi Tateno, Bernhard Walle,
"               Rajendra Badapanda, cho45, Simo Salminen, Sami Samhuri,
"               Matt Tolton, Björn Winckler, sowill, David Brown
"               Brett DiFrischia, Ali Asad Lotia, Kenneth Love
"
" Release Date: March 28, 2010
"      Version: 2.3.0
"
"        Usage: To launch the explorers:
"
"                 <Leader>lf  - Opens the filesystem explorer.
"                 <Leader>lr  - Opens the filesystem explorer from the parent
"                               directory of the current file.
"                 <Leader>lb  - Opens the buffer explorer.
"
"               You can also use the commands:
"
"                 ":LustyFilesystemExplorer"
"                 ":LustyFilesystemExplorerFromHere"
"                 ":LustyBufferExplorer"
"
"               (Personally, I map these to ,f and ,r and ,b)
"
"               The interface is intuitive.  When one of the explorers is
"               launched, a new window appears at bottom presenting a list of
"               files/dirs or buffers, and in the status bar is a prompt:
"
"                 >>
"
"               As you type, the list updates for possible matches using a
"               fuzzy matching algorithm.  Special keys include:
"
"                 <Enter>  open the selected match
"                 <Tab>    open the selected match
"                 <Esc>    cancel
"                 <C-c>    cancel
"                 <C-g>    cancel
"
"                 <C-t>    open selected match in a new [t]ab
"                 <C-o>    open selected match in a new h[o]rizontal split
"                 <C-v>    open selected match in a new [v]ertical split
"
"                 <C-n>    select the [n]ext match
"                 <C-p>    select the [p]revious match
"
"                 <C-w>    ascend one directory at prompt
"                 <C-u>    clear the prompt
"
"               Additional shortcuts for the filesystem explorer:
"
"                 <C-r>    [r]efresh directory contents
"                 <C-a>    open [a]ll files in the current list
"                 <C-e>    create a new buffer with the given name and path
"
" Buffer Explorer:
"  - The currently active buffer is highlighted.
"  - Buffers are listed without path unless needed to differentiate buffers of
"    the same name.
"
" Filesystem Explorer:
"  - Directory contents are memoized.
"  - You can recurse into and out of directories by typing the directory name
"    and a slash, e.g. "stuff/" or "../".
"  - Variable expansion, e.g. "$D" -> "/long/dir/path/".
"  - Tilde (~) expansion, e.g. "~/" -> "/home/steve/".
"  - Dotfiles are hidden by default, but are shown if the current search term
"    begins with a '.'.  To show these file at all times, set this option:
"
"       let g:LustyExplorerAlwaysShowDotFiles = 1
"
"  You can prevent certain files from appearing in the directory listings with
"  the following variable:
"
"    set wildignore=*.o,*.fasl,CVS
"
"  The above example will mask all object files, compiled lisp files, and
"  files/directories named CVS from appearing in the filesystem explorer.
"  Note that they can still be opened by being named explicitly.
"
"  See :help 'wildignore' for more information.
"
"
" Install Details:
"
" Copy this file into your $HOME/.vim/plugin directory so that it will be
" sourced on startup automatically.
"
" Note! This plugin requires Vim be compiled with Ruby interpretation.  If you
" don't know if your build of Vim has this functionality, you can check by
" running "vim --version" from the command line and looking for "+ruby".
" Alternatively, just try sourcing this script.
"
" If your version of Vim does not have "+ruby" but you would still like to
" use this plugin, you can fix it.  See the "Check for Ruby functionality"
" comment below for instructions.
"
" If you are using the same Vim configuration and plugins for multiple
" machines, some of which have Ruby and some of which don't, you may want to
" turn off the "Sorry, LustyExplorer requires ruby" warning.  You can do so
" like this (in .vimrc):
"
"   let g:LustyExplorerSuppressRubyWarning = 1
"
" GetLatestVimScripts: 1890 1 :AutoInstall: lusty-explorer.vim
"
" TODO:
" - when an edited file is in nowrap mode and the explorer is called while the
"   current window is scrolled to the right, name truncation occurs.
" - enable VimSwaps stuff
"   - set callback when pipe is ready for read and force refresh()
" - uppercase character should make flex matching case-sensitive
" - FilesystemExplorerRecursive
" - restore MRU buffer ordering for initial BufferExplorer display?
" - C-jhkl navigation to highlight a file?
" - abbrev "a" will score e.g. "m-a" higher than e.g. "ad"

" Exit quickly when already loaded.
if exists("g:loaded_lustyexplorer")
  finish
endif

if &compatible
  echohl ErrorMsg
  echo "LustyExplorer is not designed to run in &compatible mode;"
  echo "To use this plugin, first disable vi-compatible mode like so:\n"

  echo "   :set nocompatible\n"

  echo "Or even better, just create an empty .vimrc file."
  echohl none
  finish
endif

if exists("g:FuzzyFinderMode.TextMate")
  echohl WarningMsg
  echo "Warning: LustyExplorer detects the presence of fuzzyfinder_textmate;"
  echo "that plugin often interacts poorly with other Ruby plugins."
  echo "If LustyExplorer gives you an error, you can probably fix it by"
  echo "renaming fuzzyfinder_textmate.vim to zzfuzzyfinder_textmate.vim so"
  echo "that it is last in the load order."
  echohl none
endif

" Check for Ruby functionality.
if !has("ruby") || version < 700
  if !exists("g:LustyExplorerSuppressRubyWarning") ||
     \ g:LustyExplorerSuppressRubyWarning == "0"
  if !exists("g:LustyJugglerSuppressRubyWarning") ||
      \ g:LustyJugglerSuppressRubyWarning == "0"
    echohl ErrorMsg
    echon "Sorry, LustyExplorer requires ruby.  "
    echon "Here are some tips for adding it:\n"

    echo "Debian / Ubuntu:"
    echo "    # apt-get install vim-ruby\n"

    echo "Fedora:"
    echo "    # yum install vim-enhanced\n"

    echo "Gentoo:"
    echo "    # USE=\"ruby\" emerge vim\n"

    echo "FreeBSD:"
    echo "    # pkg_add -r vim+ruby\n"

    echo "Windows:"
    echo "    1. Download and install Ruby from here:"
    echo "       http://www.ruby-lang.org/"
    echo "    2. Install a Vim binary with Ruby support:"
    echo "       http://segfault.hasno.info/vim/gvim72.zip\n"

    echo "Manually (including Cygwin):"
    echo "    1. Install Ruby."
    echo "    2. Download the Vim source package (say, vim-7.0.tar.bz2)"
    echo "    3. Build and install:"
    echo "         # tar -xvjf vim-7.0.tar.bz2"
    echo "         # ./configure --enable-rubyinterp"
    echo "         # make && make install"

    echo "(If you just wish to stifle this message, set the following option:"
    echo "  let g:LustyExplorerSuppressRubyWarning = 1)"
    echohl none
  endif
  endif
  finish
endif

if ! &hidden
  echohl WarningMsg
  echo "You are running with 'hidden' mode off.  LustyExplorer may"
  echo "sometimes emit error messages in this mode -- you should turn"
  echo "it on, like so:\n"

  echo "   :set hidden\n"

  echo "Even better, put this in your .vimrc file."
  echohl none
endif

let g:loaded_lustyexplorer = "yep"

" Commands.
command LustyBufferExplorer :call <SID>LustyBufferExplorerStart()
command LustyFilesystemExplorer :call <SID>LustyFilesystemExplorerStart()
command LustyFilesystemExplorerFromHere :call <SID>LustyFilesystemExplorerFromHereStart()
command LustyGrepExplorer :call <SID>LustyGrepExplorerStart()

" Deprecated command names.
command BufferExplorer :call
  \ <SID>deprecated('BufferExplorer', 'LustyBufferExplorer')
command FilesystemExplorer :call
  \ <SID>deprecated('FilesystemExplorer', 'LustyFilesystemExplorer')
command FilesystemExplorerFromHere :call
  \ <SID>deprecated('FilesystemExplorerFromHere',
  \                 'LustyFilesystemExplorerFromHere')

function! s:deprecated(old, new)
  echohl WarningMsg
  echo ":" . a:old . " is deprecated; use :" . a:new . " instead."
  echohl none
endfunction


" Default mappings.
nmap <silent> <Leader>lf :LustyFilesystemExplorer<CR>
nmap <silent> <Leader>lr :LustyFilesystemExplorerFromHere<CR>
nmap <silent> <Leader>lb :LustyBufferExplorer<CR>
nmap <silent> <Leader>lg :LustyGrepExplorer<CR>

" Vim-to-ruby function calls.
function! s:LustyFilesystemExplorerStart()
  ruby Lusty::profile() { $lusty_filesystem_explorer.run_from_wd }
endfunction

function! s:LustyFilesystemExplorerFromHereStart()
  ruby Lusty::profile() { $lusty_filesystem_explorer.run_from_here }
endfunction

function! s:LustyBufferExplorerStart()
  ruby Lusty::profile() { $lusty_buffer_explorer.run }
endfunction

function! s:LustyGrepExplorerStart()
  ruby Lusty::profile() { $lusty_grep_explorer.run }
endfunction

function! s:LustyFilesystemExplorerCancel()
  ruby Lusty::profile() { $lusty_filesystem_explorer.cancel }
endfunction

function! s:LustyBufferExplorerCancel()
  ruby Lusty::profile() { $lusty_buffer_explorer.cancel }
endfunction

function! s:LustyGrepExplorerCancel()
  ruby Lusty::profile() { $lusty_grep_explorer.cancel }
endfunction

function! s:LustyFilesystemExplorerKeyPressed(code_arg)
  ruby Lusty::profile() { $lusty_filesystem_explorer.key_pressed }
endfunction

function! s:LustyBufferExplorerKeyPressed(code_arg)
  ruby Lusty::profile() { $lusty_buffer_explorer.key_pressed }
endfunction

function! s:LustyGrepExplorerKeyPressed(code_arg)
  ruby Lusty::profile() { $lusty_grep_explorer.key_pressed }
endfunction

ruby << EOF

require 'pathname'
# For IO#ready -- but Cygwin doesn't have io/wait.
require 'io/wait' unless RUBY_PLATFORM =~ /cygwin/
# Needed for String#each_char in Ruby 1.8 on some platforms.
require 'jcode' unless "".respond_to? :each_char
# Needed for Array#each_slice in Ruby 1.8 on some platforms.
require 'enumerator' unless [].respond_to? :each_slice

$LUSTY_PROFILING = false

if $LUSTY_PROFILING
  require 'rubygems'
  require 'ruby-prof'
end


{{RUBY_CODE_INSERTION_POINT}}

$lusty_buffer_explorer = Lusty::BufferExplorer.new
$lusty_filesystem_explorer = Lusty::FilesystemExplorer.new
$lusty_grep_explorer = Lusty::GrepExplorer.new

EOF

" vim: set sts=2 sw=2:
