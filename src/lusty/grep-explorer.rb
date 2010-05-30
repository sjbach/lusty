# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

# STEVE TODO:
# - highlighted entry should not show match in file name
# - highlighted entry doesn't highlight on second+ column
# - should not store grep entries from initial launch (i.e. buffer list)
# - some way for user to indicate case-sensitive regex
# - add slash highlighting back to file name?
# - TRUNCATED and NO ENTRIES do not highlight

module Lusty
class GrepExplorer < Explorer
  public
    def initialize
      super
      @displayer.single_column_mode = true
      @prompt = Prompt.new
      @buffer_entries = []
      @matched_strings = []

      @previous_input = ''
      @previous_grep_entries = []
      @previous_matched_strings = []
      @previous_selected_index = 0
    end

    def run
      return if @running

      @prompt.set! @previous_input
      @buffer_entries = compute_buffer_entries()
      @selected_index = @previous_selected_index
      super
    end

  private
    def title
      '[LustyExplorer-GrepBufferContents]'
    end

    def set_syntax_matching
      VIM::command 'syn clear LustyGrepEntry'
      VIM::command 'syn clear LustyGrepFileName'
      VIM::command 'syn clear LustyGrepLineNumber'
      VIM::command 'syn clear LustyGrepContext'

      # Base syntax matching -- others are set on refresh.

      grep_entry = Displayer.entry_syntaxify('.\{-}', false)
      VIM::command \
        "syn match LustyGrepEntry \"#{grep_entry}\" " \
                                  'transparent ' \
                                  'contains=LustyGrepFileName'

      VIM::command \
        'syn match LustyGrepFileName "' + Displayer::ENTRY_START_VIM_REGEX +
                                          '\zs.\{-}\ze:\d\+:" ' \
                                          'contained ' \
                                          'contains=NONE ' \
                                          'nextgroup=LustyGrepLineNumber'

      VIM::command \
        'syn match LustyGrepLineNumber ":\d\+:" ' \
                                       'contained ' \
                                       'contains=NONE ' \
                                       'nextgroup=LustyGrepContext'

      VIM::command \
        'syn match LustyGrepContext "\zs.\{-}\ze' +
                                    Displayer::ENTRY_END_VIM_REGEX + '" ' \
                                    'transparent ' \
                                    'contained ' \
                                    'contains=LustyGrepMatch'
    end

    def on_refresh
      if VIM::has_syntax?

        VIM::command 'syn clear LustyGrepMatch'

        if not @matched_strings.empty?
          sub_regexes = @matched_strings.map { |s| VIM::regex_escape(s) }
          syntax_regex = '\%(' + sub_regexes.join('\|') + '\)'
          VIM::command "syn match LustyGrepMatch \"#{syntax_regex}\" " \
                                                    "contained " \
                                                    "contains=NONE"
        end
      end
    end

    # STEVE make it a class function?
    # STEVE duplicated from BufferExplorer
    def common_prefix(entries)
      prefix = entries[0].full_name
      entries.each do |entry|
        full_name = entry.full_name
        for i in 0...prefix.length
          if full_name.length <= i or prefix[i] != full_name[i]
            prefix = prefix[0...i]
            prefix = prefix[0..(prefix.rindex('/') or -1)]
            break
          end
        end
      end
      return prefix
    end

    # STEVE make it a class function?
    # STEVE duplicated from BufferExplorer
    def compute_buffer_entries
      buffer_entries = []
      (0..VIM::Buffer.count-1).each do |i|
        buffer_entries << GrepEntry.new(VIM::Buffer[i])
      end

      # Shorten each buffer name by removing all path elements which are not
      # needed to differentiate a given name from other names.  This usually
      # results in only the basename shown, but if several buffers of the
      # same basename are opened, there will be more.

      # Group the buffers by common basename
      common_base = Hash.new { |hash, k| hash[k] = [] }
      buffer_entries.each do |entry|
        if entry.full_name
          basename = Pathname.new(entry.full_name).basename.to_s
          common_base[basename] << entry
        end
      end

      # Determine the longest common prefix for each basename group.
      basename_to_prefix = {}
      common_base.each do |base, entries|
        if entries.length > 1
          basename_to_prefix[base] = common_prefix(entries)
        end
      end

      # Compute shortened buffer names by removing prefix, if possible.
      buffer_entries.each do |entry|
        full_name = entry.full_name

        short_name = if full_name.nil?
                       '[No Name]'
                     elsif Lusty::starts_with?(full_name, "scp://")
                       full_name
                     else
                       base = Pathname.new(full_name).basename.to_s
                       prefix = basename_to_prefix[base]

                       prefix ? full_name[prefix.length..-1] \
                              : base
                     end

        entry.short_name = short_name
        entry.name = short_name  # overridden later
      end

      buffer_entries
    end

    def current_abbreviation
      @prompt.input
    end

    def compute_sorted_matches
      abbrev = current_abbreviation()

      grep_entries = @previous_grep_entries
      @matched_strings = @previous_matched_strings

      @previous_input = ''
      @previous_grep_entries = []
      @previous_matched_strings = []
      @previous_selected_index = 0

      if not grep_entries.empty?
        return grep_entries
      elsif abbrev == ''
        return @buffer_entries
      end

      begin
        regex = Regexp.compile(abbrev, Regexp::IGNORECASE)
      rescue RegexpError => e
        return []
      end

      # Used to avoid duplicating match strings, which slows down refresh.
      highlight_hash = {}

      # Search through every line of every open buffer for the
      # given expression.
      @buffer_entries.each do |entry|
        vim_buffer = entry.vim_buffer
        line_count = vim_buffer.count
        (1..line_count). each do |i|
          match = regex.match(vim_buffer[i])
          if match
            matched_str = match.to_s

            grep_entry = entry.clone()
            grep_entry.line_number = i
            grep_entry.name = "#{grep_entry.short_name}:#{i}:#{vim_buffer[i]}"
            grep_entries << grep_entry

            # Keep track of all matched strings
            unless highlight_hash[matched_str]
              @matched_strings << matched_str
              highlight_hash[matched_str] = true
            end
          end
        end
      end

      return grep_entries
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

      # Open buffer and go to the line number.
      VIM::command "silent #{cmd} #{number}"
      VIM::command "#{entry.line_number}"
    end

    def cleanup
      @previous_input = @prompt.input
      @previous_grep_entries = @current_sorted_matches
      @previous_matched_strings = @matched_strings
      @previous_selected_index = @selected_index
      super
    end
end
end

