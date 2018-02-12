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
let s:map_redirect_hack_output = ''
function! s:LustyJugglerMapRedirectHack(map_mode, key)
  if a:map_mode == 'n'
    redir => s:map_redirect_hack_output | nmap a:key | redir END
  elseif a:map_mode == 's'
    redir => s:map_redirect_hack_output | smap a:key | redir END
  elseif a:map_mode == 'x'
    redir => s:map_redirect_hack_output | xmap a:key | redir END
  elseif a:map_mode == 'o'
    redir => s:map_redirect_hack_output | omap a:key | redir END
  elseif a:map_mode == 'i'
    redir => s:map_redirect_hack_output | imap a:key | redir END
  elseif a:map_mode == 'c'
    redir => s:map_redirect_hack_output | cmap a:key | redir END
  elseif a:map_mode == 'l'
    redir => s:map_redirect_hack_output | lmap a:key | redir END
  else
    throw 'bad map mode'
  endif
endfunction

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
elsif VIM::exists?('g:LustyJugglerKeyboardLayout') and VIM::evaluate_bool('g:LustyJugglerKeyboardLayout == "neo2"')
	$lusty_juggler = LustyJ::LustyJugglerNeo2.new
else 
  $lusty_juggler = LustyJ::LustyJuggler.new
end
$lj_buffer_stack = LustyJ::BufferStack.new

EOF

" vim: set sts=2 sw=2:
