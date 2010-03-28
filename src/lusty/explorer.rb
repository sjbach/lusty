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
      @current_sorted_matches = []
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
            (@selected_index + 1) % @current_sorted_matches.size
          refresh_mode = :no_recompute
        when 16               # C-p (select previous)
          @selected_index = \
            (@selected_index - 1) % @current_sorted_matches.size
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
        @current_sorted_matches = compute_sorted_matches()
      end

      on_refresh()
      highlight_selected_index()
      @displayer.print @current_sorted_matches.map { |x| x.name }
      @prompt.print
    end

    def create_explorer_window
      # Trim out the "::" in "Lusty::FooExplorer"
      key_binding_prefix = self.class.to_s.sub(/::/,'')

      @displayer.create(key_binding_prefix)
    end

    def highlight_selected_index
      return unless VIM::has_syntax?

      entry = @current_sorted_matches[@selected_index]
      return if entry.nil?

      VIM::command "syn clear LustyExpSelected"
      VIM::command "syn match LustyExpSelected " \
	           "\"#{Displayer.vim_match_string(entry.name, false)}\" "
    end

    def choose(open_mode)
      entry = @current_sorted_matches[@selected_index]
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
      Lusty::assert(@calling_window == $curwin)
    end

    # Pure virtual methods
    # - on_refresh
    # - open_entry
    # - compute_sorted_matches

end
end

