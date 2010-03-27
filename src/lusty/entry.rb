# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

# Used in FilesystemExplorer
module Lusty
class Entry
  attr_accessor :name, :current_score
  def initialize(name)
    @name = name
    @current_score = 0.0
  end
end
end

# Used in BufferExplorer
module Lusty
class BufferEntry < Entry
  attr_accessor :full_name, :vim_buffer
  def initialize(vim_buffer)
    @full_name = vim_buffer.name
    @vim_buffer = vim_buffer
    @name = "::UNSET::"
    @current_score = 0.0
  end
end
end

