# Copyright (C) 2007 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

module LustyM
class BufferExplorer < Explorer
  public
    def initialize
      super
      @prompt = Prompt.new
      @buffer_entries = []
    end

    def run
      unless @running
        @prompt.clear!
        @curbuf_at_start = VIM::Buffer.current
        @buffer_entries = BufferEntry::compute_buffer_entries()
        @buffer_entries.each do |e|
          # Show modification indicator
          e.label = e.short_name
          e.label << " [+]" if e.vim_buffer.modified?
          # Disabled: show buffer number next to name
          #e.label << " #{buffer.number.to_s}"
        end

        @selected_index = 0
        super
      end
    end

    def key_pressed()
      i = VIM::evaluate("a:code_arg").to_i

      case i
        when 4                # C-d unload selected buffer
          unload_selected_buffer()
          refresh(:no_recompute)
        else
          super
      end
    end

  private
    def title
      'LustyExplorer--Buffers'
    end

    def set_syntax_matching
      # Base highlighting -- more is set on refresh.
      if VIM::has_syntax?
        VIM::command 'syn match LustySlash "/" contained'
        VIM::command 'syn match LustyDir "\%(\S\+ \)*\S\+/" ' \
                                         'contains=LustySlash'
        VIM::command 'syn match LustyModified " \[+\]"'
      end
    end

    def curbuf_match_string
      curbuf = @buffer_entries.find { |x| x.vim_buffer == @curbuf_at_start }
      if curbuf
        escaped = VIM::regex_escape(curbuf.label)
        Display.entry_syntaxify(escaped, @prompt.insensitive?)
      else
        ""
      end
    end

    def on_refresh
      # Highlighting for the current buffer name.
      if VIM::has_syntax?
        VIM::command 'syn clear LustyCurrentBuffer'
        VIM::command 'syn match LustyCurrentBuffer ' \
                     "\"#{curbuf_match_string()}\" " \
                     'contains=LustyModified'
      end
    end

    def current_abbreviation
      @prompt.input
    end

    def compute_sorted_matches
      abbrev = current_abbreviation()

      if abbrev.length == 0
        # Take (current) MRU order if we have no abbreviation.
        @buffer_entries
      else
        matching_entries = \
          @buffer_entries.select { |x|
            x.current_score = Mercury.score(x.short_name, abbrev)
            x.current_score != 0.0
          }

        # Sort by score.
        matching_entries.sort! { |x, y|
          if x.current_score == y.current_score
            x.mru_placement <=> y.mru_placement
          else
            y.current_score <=> x.current_score
          end
        }
      end
    end

    def open_entry(entry, open_mode)
      cleanup()
      LustyM::assert($curwin == @calling_window)

      number = entry.vim_buffer.number
      LustyM::assert(number)

      cmd = case open_mode
            when :current_tab
              "b"
            when :new_tab
              # For some reason just using tabe or e gives an error when
              # the alternate-file isn't set.
              "tab split | b"
            when :new_split
	      "sp | b"
            when :new_vsplit
	      "vs | b"
            else
              LustyM::assert(false, "bad open mode")
            end

      VIM::command "silent #{cmd} #{number}"
    end

    def unload_selected_buffer
      entry = @current_sorted_matches[@selected_index]
      return if entry.nil?

      previous_selected_index = @selected_index

      unload_buffer(entry)
      run()

      # restore position of selected item
      if previous_selected_index >= @current_sorted_matches.size
        @selected_index = previous_selected_index - 1
      else
        @selected_index = previous_selected_index
      end
    end

    def unload_buffer(entry)
      cleanup()
      number = entry.vim_buffer.number
      LustyE::assert(number)

      VIM::command "silent bdelete! #{number}"
    end
end
end

