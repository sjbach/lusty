# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

class IO
  # STEVE put in Lusty
  def ready_for_read?
    if self.respond_to? :ready?
      ready?
    else
      result = IO.select([self], nil, nil, 0)
      result && (result.first.first == self)
    end
  end
end

