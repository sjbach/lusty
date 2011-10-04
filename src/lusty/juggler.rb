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
      if $lj_buffer_stack.length <= 1
        VIM::pretty_msg("PreProc", "No other buffers")
        return
      end

      # If already running, highlight next buffer
      if @running and LustyJuggler::alt_tab_mode_active?
        @last_pressed = (@last_pressed % $lj_buffer_stack.length) + 1;
        print_buffer_list(@last_pressed)
        return
      end

      return if @running
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

      @key_mappings_map = Hash.new { |hash, k| hash[k] = [] }

      # Selection keys.
      @@KEYS.keys.each do |c|
        map_key(c, ":call <SID>LustyJugglerKeyPressed('#{c}')<CR>")
      end
      # Can't use '<CR>' as an argument to :call func for some reason.
      map_key("<CR>", ":call <SID>LustyJugglerKeyPressed('ENTER')<CR>")
      map_key("<Tab>", ":call <SID>LustyJugglerKeyPressed('TAB')<CR>")

      # Split opener keys
      map_key("v", ":call <SID>LustyJugglerKeyPressed('v')<CR>")
      map_key("b", ":call <SID>LustyJugglerKeyPressed('b')<CR>")

      # Left and Right keys
      map_key("<Esc>OD", ":call <SID>LustyJugglerKeyPressed('Left')<CR>")
      map_key("<Esc>OC", ":call <SID>LustyJugglerKeyPressed('Right')<CR>")
      map_key("<Left>",  ":call <SID>LustyJugglerKeyPressed('Left')<CR>")
      map_key("<Right>", ":call <SID>LustyJugglerKeyPressed('Right')<CR>")

      # Cancel keys.
      map_key("i", ":call <SID>LustyJugglerCancel()<CR>")
      map_key("q", ":call <SID>LustyJugglerCancel()<CR>")
      map_key("<Esc>", ":call <SID>LustyJugglerCancel()<CR>")
      map_key("<C-c>", ":call <SID>LustyJugglerCancel()<CR>")
      map_key("<BS>", ":call <SID>LustyJugglerCancel()<CR>")
      map_key("<Del>", ":call <SID>LustyJugglerCancel()<CR>")
      map_key("<C-h>", ":call <SID>LustyJugglerCancel()<CR>")

      @last_pressed = 2 if LustyJuggler::alt_tab_mode_active?
      print_buffer_list(@last_pressed)
    end

    def key_pressed()
      c = VIM::evaluate("a:code_arg")

      if @last_pressed.nil? and c == 'ENTER'
        cleanup()
      elsif @last_pressed and (@@KEYS[c] == @last_pressed or c == 'ENTER')
        choose(@last_pressed)
        cleanup()
      elsif @last_pressed and %w(v b).include?(c)
        c=='v' ? vsplit(@last_pressed) : hsplit(@last_pressed)
        cleanup()
      elsif c == 'Left'
        @last_pressed = (@last_pressed.nil?) ? 0 : (@last_pressed)
        @last_pressed = (@last_pressed - 1) < 1 ? $lj_buffer_stack.length : (@last_pressed - 1)
        print_buffer_list(@last_pressed)
      elsif c == 'Right'
        @last_pressed = (@last_pressed.nil?) ? 0 : (@last_pressed)
        @last_pressed = (@last_pressed + 1) > $lj_buffer_stack.length ? 1 : (@last_pressed + 1)
        print_buffer_list(@last_pressed)
      else
        @last_pressed = @@KEYS[c]
        print_buffer_list(@last_pressed)
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
        unmap_key(c)
      end
      unmap_key("<CR>")
      unmap_key("<Tab>")

      unmap_key("v")
      unmap_key("b")

      unmap_key("i")
      unmap_key("q")
      unmap_key("<Esc>")
      unmap_key("<C-c>")
      unmap_key("<BS>")
      unmap_key("<Del>")
      unmap_key("<C-h>")
      unmap_key("<Esc>OC")
      unmap_key("<Esc>OD")
      unmap_key("<Left>")
      unmap_key("<Right>")

      @running = false
      VIM::message ''
      VIM::command 'redraw'  # Prevents "Press ENTER to continue" message.
    end

  private
    def self.alt_tab_mode_active?
       return (VIM::exists?("g:LustyJugglerAltTabMode") and
               VIM::evaluate("g:LustyJugglerAltTabMode").to_i != 0)
    end

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
    
    def vsplit(i)
      buf = $lj_buffer_stack.num_at_pos(i)
      VIM::command "vert sb #{buf}"
    end
    
    def hsplit(i)
      buf = $lj_buffer_stack.num_at_pos(i)
      VIM::command "sb #{buf}"
    end

    def map_key(key, action)
      ['n','s','x','o','i','c','l'].each do |mode|
        VIM::command "let s:maparg_holder = maparg('#{key}', '#{mode}')"
        if VIM::evaluate_bool("s:maparg_holder != ''")
          orig_rhs = VIM::evaluate("s:maparg_holder")
          if VIM::has_ext_maparg?
            VIM::command "let s:maparg_dict_holder = maparg('#{key}', '#{mode}', 0, 1)"
            nore    = VIM::evaluate_bool("s:maparg_dict_holder['noremap']") ? 'nore'      : ''
            silent  = VIM::evaluate_bool("s:maparg_dict_holder['silent']")  ? ' <silent>' : ''
            expr    = VIM::evaluate_bool("s:maparg_dict_holder['expr']")    ? ' <expr>'   : ''
            buffer  = VIM::evaluate_bool("s:maparg_dict_holder['buffer']")  ? ' <buffer>' : ''
            restore_cmd = "#{mode}#{nore}map#{silent}#{expr}#{buffer} #{key} #{orig_rhs}"
          else
            nore = LustyM::starts_with?(orig_rhs, '<Plug>') ? '' : 'nore'
            restore_cmd = "#{mode}#{nore}map <silent> #{key} #{orig_rhs}"
          end
          @key_mappings_map[key] << [ mode, restore_cmd ]
        end
        VIM::command "#{mode}noremap <silent> #{key} #{action}"
      end
    end

    def unmap_key(key)
      #first, unmap lusty_juggler's maps
      ['n','s','x','o','i','c','l'].each do |mode|
        VIM::command "#{mode}unmap <silent> #{key}"
      end

      if @key_mappings_map.has_key?(key)
        @key_mappings_map[key].each do |a|
          mode, restore_cmd = *a
          # for mappings that have on the rhs \|, the \ is somehow stripped
          restore_cmd.gsub!("|", "\\|")
          VIM::command restore_cmd
        end
      end
    end
end
end

