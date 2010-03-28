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
        @buffer_entries = compute_buffer_entries()
        super
      end
    end

  private
    def title
      '[LustyExplorer-Buffers]'
    end

    def curbuf_match_string
      curbuf = @buffer_entries.find { |x| x.vim_buffer == @curbuf_at_start }
      if curbuf
        Displayer.vim_match_string(curbuf.name, @prompt.insensitive?)
      else
        ""
      end
    end

    def on_refresh
      # Highlighting for the current buffer name.
      if VIM::has_syntax?
        VIM::command 'syn clear LustyExpCurrentBuffer'
        VIM::command 'syn match LustyExpCurrentBuffer ' \
                     "\"#{curbuf_match_string()}\" " \
                     'contains=LustyExpModified'
      end
    end

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

    def compute_buffer_entries
      buffer_entries = []
      (0..VIM::Buffer.count-1).each do |i|
        buffer_entries << BufferEntry.new(VIM::Buffer[i])
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

        # Disabled: show buffer number next to name
        #short_name << ' ' + buffer.number.to_s

        # Show modification indicator
        short_name << (entry.vim_buffer.modified? ? " [+]" : "")

        entry.name = short_name
      end

      buffer_entries
    end

    def current_abbreviation
      @prompt.input
    end

    def all_entries
      @buffer_entries
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

