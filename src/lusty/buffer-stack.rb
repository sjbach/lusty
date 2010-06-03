# Copyright (C) 2008-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

# Maintain MRU ordering.
module Lusty
class BufferStack
  public
    def initialize
      @stack = []

      (0..VIM::Buffer.count-1).each do |i|
        @stack << VIM::Buffer[i].number
      end
    end

    # Switch to the previous buffer (the one you were using before the
    # current one).  This is basically a smarter replacement for :b#,
    # accounting for the situation where your previous buffer no longer
    # exists.
    def juggle_previous
      buf = num_at_pos(2)
      VIM::command "b #{buf}"
    end

    def names
      # Get the last 10 buffer names by MRU.  Show only as much of
      # the name as necessary to differentiate between buffers of
      # the same name.
      cull!
      names = @stack.collect { |i| VIM::bufname(i) }.reverse[0,10]
      shorten_paths(names)
    end

    def num_at_pos(i)
      cull!
      return @stack[-i] ? @stack[-i] : @stack.first
    end

    def length
      cull!
      return @stack.length
    end

    def push
      @stack.delete $curbuf.number
      @stack << $curbuf.number
    end

    def pop
      number = VIM::evaluate('bufnr(expand("<afile>"))')
      @stack.delete number
    end

  private
    def cull!
      # Remove empty buffers.
      @stack.delete_if { |x| not VIM::evaluate_bool("bufexists(#{x})") }
    end

    # STEVE to Lusty:: to be common with explorer
    def shorten_paths(buffer_names)
      # Shorten each buffer name by removing all path elements which are not
      # needed to differentiate a given name from other names.  This usually
      # results in only the basename shown, but if several buffers of the
      # same basename are opened, there will be more.

      # Group the buffers by common basename
      common_base = Hash.new { |hash, k| hash[k] = [] }
      buffer_names.each do |name|
        basename = Pathname.new(name).basename.to_s
        common_base[basename] << name
      end

      # Determine the longest common prefix for each basename group.
      basename_to_prefix = {}
      common_base.each do |k, names|
        if names.length > 1
          basename_to_prefix[k] = common_prefix(names)
        end
      end

      # Shorten each buffer_name by removing the prefix.
      buffer_names.map { |name|
        base = Pathname.new(name).basename.to_s
        prefix = basename_to_prefix[base]
        prefix ? name[prefix.length..-1] \
               : base
      }
    end

    # STEVE to Lusty:: to be common with explorer
    def common_prefix(paths)
      prefix = paths[0]
      for path in paths
        for i in 0...prefix.length
          if path.length <= i or prefix[i] != path[i]
            prefix = prefix[0...i]
            prefix = prefix[0..(prefix.rindex('/') or -1)]
            break
          end
        end
      end
      return prefix
    end
end

end

