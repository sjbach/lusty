# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

# STEVE rename name to be something else; designation?
# STEVE perhaps there should be a FilesystemEntry? so we don't need current_score in Entry

module Lusty

# Abstract base class.
class Entry
  attr_accessor :name
  def initialize(name)
    @name = name
  end
end

# Used in FilesystemExplorer
class FilesystemEntry < Entry
  attr_accessor :current_score
  def initialize(name)
    super(name)
    @current_score = 0.0
  end
end

# Used in BufferExplorer
class BufferEntry < Entry
  attr_accessor :full_name, :vim_buffer, :current_score
  def initialize(vim_buffer)
    super("::UNSET::")
    @full_name = vim_buffer.name
    @vim_buffer = vim_buffer
    @current_score = 0.0
  end
end

# Used in GrepExplorer
class GrepEntry < Entry
  attr_accessor :full_name, :short_name, :vim_buffer, :line_number
  def initialize(vim_buffer)
    super("::UNSET::")
    @full_name = vim_buffer.name
    @vim_buffer = vim_buffer
    @short_name = "::UNSET::"  # STEVE << necessary?
    @line_number = 0
  end
end

end

