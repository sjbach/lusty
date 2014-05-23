" Vim-to-ruby function calls.
function! lustyjuggler#LustyJugglerStart()
  ruby LustyJ::profile() { $lusty_juggler.run }
endfunction

function! s:LustyJugglerKeyPressed(code_arg)
  ruby LustyJ::profile() { $lusty_juggler.key_pressed }
endfunction

function! s:LustyJugglerCancel()
  ruby LustyJ::profile() { $lusty_juggler.cleanup }
endfunction

function! lustyjuggler#LustyJugglePreviousRun()
  ruby LustyJ::profile() { $lj_buffer_stack.juggle_previous }
endfunction

" Setup the autocommands that handle buffer MRU ordering.
augroup LustyJuggler
  autocmd!
  autocmd BufAdd,BufEnter * ruby LustyJ::profile() { $lj_buffer_stack.push }
  autocmd BufDelete * ruby LustyJ::profile() { $lj_buffer_stack.pop }
  autocmd BufWipeout * ruby LustyJ::profile() { $lj_buffer_stack.pop }
augroup End

" Used to work around a flaw in Vim's ruby bindings.
let s:maparg_holder = 0
let s:maparg_dict_holder = { }

ruby << EOF

require 'pathname'

$LUSTY_PROFILING = false

if $LUSTY_PROFILING
  require 'rubygems'
  require 'ruby-prof'
end


{{RUBY_CODE_INSERTION_POINT}}

if VIM::exists?('g:LustyJugglerKeyboardLayout') and VIM::evaluate_bool('g:LustyJugglerKeyboardLayout == "dvorak"')
  $lusty_juggler = LustyJ::LustyJugglerDvorak.new
elsif VIM::exists?('g:LustyJugglerKeyboardLayout') and VIM::evaluate_bool('g:LustyJugglerKeyboardLayout == "colemak"')
  $lusty_juggler = LustyJ::LustyJugglerColemak.new
elsif VIM::exists?('g:LustyJugglerKeyboardLayout') and VIM::evaluate_bool('g:LustyJugglerKeyboardLayout == "bépo"')
	$lusty_juggler = LustyJ::LustyJugglerBepo.new
elsif VIM::exists?('g:LustyJugglerKeyboardLayout') and VIM::evaluate_bool('g:LustyJugglerKeyboardLayout == "azerty"')
	$lusty_juggler = LustyJ::LustyJugglerAzerty.new
else 
  $lusty_juggler = LustyJ::LustyJuggler.new
end
$lj_buffer_stack = LustyJ::BufferStack.new

EOF

" vim: set sts=2 sw=2:
