# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

# Abstract base class; extended as BufferExplorer, FilesystemExplorer
module Lusty
class Explorer
  public
    def initialize
      @settings = SavedSettings.new
      @displayer = Displayer.new title()
      @prompt = nil
      @ordered_matching_entries = []
      @running = false
    end

    def run
      return if @running

      @settings.save
      @running = true
      @calling_window = $curwin
      @saved_alternate_bufnum = if VIM::evaluate_bool("expand('#') == ''")
                                  nil
                                else
                                  VIM::evaluate("bufnr(expand('#'))")
                                end
      @selected_index = 0
      create_explorer_window()
      refresh(:full)
    end

    def key_pressed()
      # Grab argument from the Vim function.
      i = VIM::evaluate("a:code_arg").to_i
      refresh_mode = :full

      case i
        when 32..126          # Printable characters
          c = i.chr
          @prompt.add! c
          @selected_index = 0
        when 8                # Backspace/Del/C-h
          @prompt.backspace!
          @selected_index = 0
        when 9, 13            # Tab and Enter
          choose(:current_tab)
          @selected_index = 0
        when 23               # C-w (delete 1 dir backward)
          @prompt.up_one_dir!
          @selected_index = 0
        when 14               # C-n (select next)
          @selected_index = \
            (@selected_index + 1) % @ordered_matching_entries.size
          refresh_mode = :no_recompute
        when 16               # C-p (select previous)
          @selected_index = \
            (@selected_index - 1) % @ordered_matching_entries.size
          refresh_mode = :no_recompute
        when 15               # C-o choose in new horizontal split
          choose(:new_split)
          @selected_index = 0
        when 20               # C-t choose in new tab
          choose(:new_tab)
          @selected_index = 0
        when 21               # C-u clear prompt
          @prompt.clear!
          @selected_index = 0
        when 22               # C-v choose in new vertical split
          choose(:new_vsplit)
          @selected_index = 0
      end

      refresh(refresh_mode)
    end

    def cancel
      if @running
        cleanup()
        # fix alternate file
        if @saved_alternate_bufnum
          cur = $curbuf
          VIM::command "silent b #{@saved_alternate_bufnum}"
          VIM::command "silent b #{cur.number}"
        end

        if $LUSTY_PROFILING
          outfile = File.new('rbprof.html', 'a')
          #RubyProf::CallTreePrinter.new(RubyProf.stop).print(outfile)
          RubyProf::GraphHtmlPrinter.new(RubyProf.stop).print(outfile)
        end
      end
    end

  private
    def refresh(mode)
      return if not @running

      if mode == :full
        @ordered_matching_entries = compute_ordered_matching_entries()
      end

      on_refresh()
      highlight_selected_index()
      @displayer.print @ordered_matching_entries.map { |x| x.name }
      @prompt.print
    end

    def create_explorer_window

      @displayer.create

      # Setup key mappings to reroute user input.

      # Non-special printable characters.
      printables =  '/!"#$%&\'()*+,-.0123456789:<=>?#@"' \
                    'ABCDEFGHIJKLMNOPQRSTUVWXYZ' \
                    '[]^_`abcdefghijklmnopqrstuvwxyz{}~'

      map = "noremap <silent> <buffer>"
      name = self.class.to_s.sub(/.*::/,'')  # Trim out "Lusty::"

      printables.each_byte do |b|
        VIM::command "#{map} <Char-#{b}> :call <SID>Lusty#{name}KeyPressed(#{b})<CR>"
      end

      # Special characters
      VIM::command "#{map} <Tab>    :call <SID>Lusty#{name}KeyPressed(9)<CR>"
      VIM::command "#{map} <Bslash> :call <SID>Lusty#{name}KeyPressed(92)<CR>"
      VIM::command "#{map} <Space>  :call <SID>Lusty#{name}KeyPressed(32)<CR>"
      VIM::command "#{map} \026|    :call <SID>Lusty#{name}KeyPressed(124)<CR>"

      VIM::command "#{map} <BS>     :call <SID>Lusty#{name}KeyPressed(8)<CR>"
      VIM::command "#{map} <Del>    :call <SID>Lusty#{name}KeyPressed(8)<CR>"
      VIM::command "#{map} <C-h>    :call <SID>Lusty#{name}KeyPressed(8)<CR>"

      VIM::command "#{map} <CR>     :call <SID>Lusty#{name}KeyPressed(13)<CR>"
      VIM::command "#{map} <S-CR>   :call <SID>Lusty#{name}KeyPressed(10)<CR>"
      VIM::command "#{map} <C-a>    :call <SID>Lusty#{name}KeyPressed(1)<CR>"

      VIM::command "#{map} <Esc>    :call <SID>Lusty#{name}Cancel()<CR>"
      VIM::command "#{map} <C-c>    :call <SID>Lusty#{name}Cancel()<CR>"
      VIM::command "#{map} <C-g>    :call <SID>Lusty#{name}Cancel()<CR>"

      VIM::command "#{map} <C-w>    :call <SID>Lusty#{name}KeyPressed(23)<CR>"
      VIM::command "#{map} <C-n>    :call <SID>Lusty#{name}KeyPressed(14)<CR>"
      VIM::command "#{map} <C-p>    :call <SID>Lusty#{name}KeyPressed(16)<CR>"
      VIM::command "#{map} <C-o>    :call <SID>Lusty#{name}KeyPressed(15)<CR>"
      VIM::command "#{map} <C-t>    :call <SID>Lusty#{name}KeyPressed(20)<CR>"
      VIM::command "#{map} <C-v>    :call <SID>Lusty#{name}KeyPressed(22)<CR>"
      VIM::command "#{map} <C-e>    :call <SID>Lusty#{name}KeyPressed(5)<CR>"
      VIM::command "#{map} <C-r>    :call <SID>Lusty#{name}KeyPressed(18)<CR>"
      VIM::command "#{map} <C-u>    :call <SID>Lusty#{name}KeyPressed(21)<CR>"
    end

    def highlight_selected_index
      return unless VIM::has_syntax?

      entry = @ordered_matching_entries[@selected_index]
      return if entry.nil?

      VIM::command "syn clear LustyExpSelected"
      VIM::command "syn match LustyExpSelected " \
	           "\"#{Displayer.vim_match_string(entry.name, false)}\" "
    end

    def compute_ordered_matching_entries
      abbrev = current_abbreviation()
      unordered = matching_entries()

      # Sort alphabetically if there's just a dot or we have no abbreviation,
      # otherwise it just looks weird.
      if abbrev.length == 0 or abbrev == '.'
        unordered.sort! { |x, y| x.name <=> y.name }
      else
        # Sort by score.
        unordered.sort! { |x, y| y.current_score <=> x.current_score }
      end
    end

    def matching_entries
      abbrev = current_abbreviation()
      all_entries().select { |x|
        x.current_score = LiquidMetal.score(x.name, abbrev)
        x.current_score != 0.0
      }
    end

    def choose(open_mode)
      entry = @ordered_matching_entries[@selected_index]
      return if entry.nil?
      @selected_index = 0
      open_entry(entry, open_mode)
    end

    def cleanup
      @displayer.close
      Window.select @calling_window
      @settings.restore
      @running = false
      VIM::message ""
      assert(@calling_window == $curwin)
    end
end
end

