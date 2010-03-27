# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

module Lusty
  def self.option_set?(opt_name)
    opt_name = "g:LustyExplorer" + opt_name
    VIM::evaluate_bool("exists('#{opt_name}') && #{opt_name} != '0'")
  end

  def self.profile
    # Profile (if enabled) and provide better
    # backtraces when there's an error.

    if $LUSTY_PROFILING
      if not RubyProf.running?
        RubyProf.measure_mode = RubyProf::WALL_TIME
        RubyProf.start
      else
        RubyProf.resume
      end
    end

    begin
      yield
    rescue Exception => e
      puts e
      puts e.backtrace
    end

    if $LUSTY_PROFILING and RubyProf.running?
      RubyProf.pause
    end
  end

  class AssertionError < StandardError ; end

  def self.assert(condition, message = 'assertion failure')
    raise AssertionError.new(message) unless condition
  end

  def self.d(s)
    # (Debug print)
    $stderr.puts s
  end
end

