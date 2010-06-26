# Copyright (C) 2008-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

module LustyM
class LustyJuggler
  private
    @@KEYS = { "a" => 1,
               "s" => 2,
               "d" => 3,
               "f" => 4,
               "g" => 5,
               "h" => 6,
               "j" => 7,
               "k" => 8,
               "l" => 9,
               ";" => 10,
               "1" => 1,
               "2" => 2,
               "3" => 3,
               "4" => 4,
               "5" => 5,
               "6" => 6,
               "7" => 7,
               "8" => 8,
               "9" => 9,
               "0" => 10 }

  public
    def initialize
      @running = false
      @last_pressed = nil
      @name_bar = NameBar.new
    end

    def run
      return if @running

      if $lj_buffer_stack.length <= 1
        VIM::pretty_msg("PreProc", "No other buffers")
        return
      end

      @running = true

      # Need to zero the timeout length or pressing 'g' will hang.
      @ruler = VIM::evaluate_bool("&ruler")
      @showcmd = VIM::evaluate_bool("&showcmd")
      @showmode = VIM::evaluate_bool("&showmode")
      @timeoutlen = VIM::evaluate("&timeoutlen")
      VIM::set_option 'timeoutlen=0'
      VIM::set_option 'noruler'
      VIM::set_option 'noshowcmd'
      VIM::set_option 'noshowmode'

      # Selection keys.
      @@KEYS.keys.each do |c|
        VIM::command "noremap <silent> #{c} :call <SID>LustyJugglerKeyPressed('#{c}')<CR>"
      end
      # Can't use '<CR>' as an argument to :call func for some reason.
      VIM::command "noremap <silent> <CR>  :call <SID>LustyJugglerKeyPressed('ENTER')<CR>"
      #VIM::command "noremap <silent> <Tab>  :call <SID>LustyJugglerKeyPressed('TAB')<CR>"

      # Cancel keys.
      VIM::command "noremap <silent> q     :call <SID>LustyJugglerCancel()<CR>"
      VIM::command "noremap <silent> <Esc> :call <SID>LustyJugglerCancel()<CR>"
      VIM::command "noremap <silent> <C-c> :call <SID>LustyJugglerCancel()<CR>"
      VIM::command "noremap <silent> <BS>  :call <SID>LustyJugglerCancel()<CR>"
      VIM::command "noremap <silent> <Del> :call <SID>LustyJugglerCancel()<CR>"
      VIM::command "noremap <silent> <C-h> :call <SID>LustyJugglerCancel()<CR>"

      print_buffer_list()
    end

    def key_pressed()
      c = VIM::evaluate("a:code_arg")

      if @last_pressed.nil? and c == 'ENTER'
        cleanup()
      elsif @last_pressed and (c == @last_pressed or c == 'ENTER')
        choose(@@KEYS[@last_pressed])
        cleanup()
      else
        print_buffer_list(@@KEYS[c])
        @last_pressed = c
      end
    end

    # Restore settings, mostly.
    def cleanup
      @last_pressed = nil

      VIM::set_option "timeoutlen=#{@timeoutlen}"
      VIM::set_option "ruler" if @ruler
      VIM::set_option "showcmd" if @showcmd
      VIM::set_option "showmode" if @showmode

      @@KEYS.keys.each do |c|
        VIM::command "unmap <silent> #{c}"
      end
      VIM::command "unmap <silent> <CR>"
      #VIM::command "unmap <silent> <Tab>"

      VIM::command "unmap <silent> q"
      VIM::command "unmap <silent> <Esc>"
      VIM::command "unmap <silent> <C-c>"
      VIM::command "unmap <silent> <BS>"
      VIM::command "unmap <silent> <Del>"
      VIM::command "unmap <silent> <C-h>"

      @running = false
      VIM::message ''
      VIM::command 'redraw'  # Prevents "Press ENTER to continue" message.
    end

  private
    def print_buffer_list(highlighted_entry = nil)
      # If the user pressed a key higher than the number of open buffers,
      # highlight the highest (see also BufferStack.num_at_pos()).

      @name_bar.selected_buffer = \
        if highlighted_entry
          # Correct for zero-based array.
          [highlighted_entry, $lj_buffer_stack.length].min - 1
        else
          nil
        end

      @name_bar.print
    end

    def choose(i)
      buf = $lj_buffer_stack.num_at_pos(i)
      VIM::command "b #{buf}"
    end
end
end

