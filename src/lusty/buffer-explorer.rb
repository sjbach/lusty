# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

module Lusty
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
          e.label << " [+]" if e.vim_buffer.modified?
          # Disabled: show buffer number next to name
          #e.label << " #{buffer.number.to_s}"
        end

        @selected_index = 0
        super
      end
    end

  private
    def title
      '[LustyExplorer-Buffers]'
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
        # Sort alphabetically if we have no abbreviation.
        @buffer_entries.sort { |x, y| x.label <=> y.label }
      else
        matching_entries = \
          @buffer_entries.select { |x|
            x.current_score = LiquidMetal.score(x.label, abbrev)
            x.current_score != 0.0
          }

        # Sort by score.
        matching_entries.sort! { |x, y|
          y.current_score <=> x.current_score
        }
      end
    end

    def open_entry(entry, open_mode)
      cleanup()
      Lusty::assert($curwin == @calling_window)

      number = entry.vim_buffer.number
      Lusty::assert(number)

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
              Lusty::assert(false, "bad open mode")
            end

      VIM::command "silent #{cmd} #{number}"
    end
end
end

