" Vim-to-ruby function calls.
function! lustyexplorer#LustyFilesystemExplorerStart(path)
  ruby LustyE::profile() {
       \  $lusty_filesystem_explorer.run_from_path(VIM::evaluate("a:path"))
       \}
endfunction

function! lustyexplorer#LustyBufferExplorerStart()
  ruby LustyE::profile() { $lusty_buffer_explorer.run }
endfunction

function! lustyexplorer#LustyBufferGrepStart()
  ruby LustyE::profile() { $lusty_buffer_grep.run }
endfunction

function! s:LustyFilesystemExplorerCancel()
  ruby LustyE::profile() { $lusty_filesystem_explorer.cancel }
endfunction

function! s:LustyBufferExplorerCancel()
  ruby LustyE::profile() { $lusty_buffer_explorer.cancel }
endfunction

function! s:LustyBufferGrepCancel()
  ruby LustyE::profile() { $lusty_buffer_grep.cancel }
endfunction

function! s:LustyFilesystemExplorerKeyPressed(code_arg)
  ruby LustyE::profile() { $lusty_filesystem_explorer.key_pressed }
endfunction

function! s:LustyBufferExplorerKeyPressed(code_arg)
  ruby LustyE::profile() { $lusty_buffer_explorer.key_pressed }
endfunction

function! s:LustyBufferGrepKeyPressed(code_arg)
  ruby LustyE::profile() { $lusty_buffer_grep.key_pressed }
endfunction

" Setup the autocommands that handle buffer MRU ordering.
augroup LustyExplorer
  autocmd!
  autocmd BufAdd,BufEnter * ruby LustyE::profile() { $le_buffer_stack.push }
  autocmd BufDelete * ruby LustyE::profile() { $le_buffer_stack.pop }
  autocmd BufWipeout * ruby LustyE::profile() { $le_buffer_stack.pop }
augroup End

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

$lusty_buffer_explorer = LustyE::BufferExplorer.new
$lusty_filesystem_explorer = LustyE::FilesystemExplorer.new
$lusty_buffer_grep = LustyE::BufferGrep.new
$le_buffer_stack = LustyE::BufferStack.new

EOF

" vim: set sts=2 sw=2:
