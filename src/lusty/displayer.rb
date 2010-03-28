# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

# Manage the explorer buffer.
module Lusty
class Displayer
  private
    @@COLUMN_SEPARATOR = "    "
    @@NO_MATCHES_STRING = "-- NO MATCHES --"
    @@TRUNCATED_STRING = "-- TRUNCATED --"

  public
    def self.vim_match_string(s, case_insensitive)
      # Create a match regex string for the given s.  This is for a Vim regex,
      # not for a Ruby regex.

      str = '\%(^\|' + @@COLUMN_SEPARATOR + '\)' \
            '\zs' + VIM::regex_escape(s) + '\%( \[+\]\)\?' + '\ze' \
            '\%(\s*$\|' + @@COLUMN_SEPARATOR + '\)'

      str << '\c' if case_insensitive

      return str
    end

    def initialize(title)
      @title = title
      @window = nil
      @buffer = nil

      # Hashes by range, e.g. 0..2, representing the width
      # of the column bounded by that range.
      @col_range_widths = {}
    end

    def create
      # Make a window for the displayer and move there.
      VIM::command "silent! botright split #{@title}"

      @window = $curwin
      @buffer = $curbuf

      # Displayer buffer is special.
      VIM::command "setlocal bufhidden=delete"
      VIM::command "setlocal buftype=nofile"
      VIM::command "setlocal nomodifiable"
      VIM::command "setlocal noswapfile"
      VIM::command "setlocal nowrap"
      VIM::command "setlocal nonumber"
      VIM::command "setlocal foldcolumn=0"
      VIM::command "setlocal nocursorline"
      VIM::command "setlocal nospell"
      VIM::command "setlocal nobuflisted"
      VIM::command "setlocal textwidth=0"
      VIM::command "setlocal noreadonly"

      # (Update SavedSettings if adding to below.)
      VIM::set_option "timeoutlen=0"
      VIM::set_option "noinsertmode"
      VIM::set_option "noshowcmd"
      VIM::set_option "nolist"
      VIM::set_option "report=9999"
      VIM::set_option "sidescroll=0"
      VIM::set_option "sidescrolloff=0"

      # TODO -- cpoptions?

      if VIM::has_syntax?
        VIM::command 'syn match LustyExpSlash "/" contained'
        VIM::command 'syn match LustyExpDir "\zs\%(\S\+ \)*\S\+/\ze" ' \
                                            'contains=LustyExpSlash'

        VIM::command 'syn match LustyExpModified " \[+\]"'

        VIM::command 'syn match LustyExpNoEntries "\%^\s*' \
                                                  "#{@@NO_MATCHES_STRING}" \
                                                  '\s*\%$"'

        VIM::command 'syn match LustyExpTruncated "^\s*' \
                                                  "#{@@TRUNCATED_STRING}" \
                                                  '\s*$"'

        VIM::command 'highlight link LustyExpDir Directory'
        VIM::command 'highlight link LustyExpSlash Function'
        VIM::command 'highlight link LustyExpSelected Type'
        VIM::command 'highlight link LustyExpModified Special'
        VIM::command 'highlight link LustyExpCurrentBuffer Constant'
        VIM::command 'highlight link LustyExpOpenedFile PreProc'
        VIM::command 'highlight link LustyExpFileWithSwap WarningMsg'
        VIM::command 'highlight link LustyExpNoEntries ErrorMsg'
        VIM::command 'highlight link LustyExpTruncated Visual'
      end
    end

    def print(strings)
      Window.select(@window) || return

      if strings.empty?
        print_no_entries()
        return
      end

      row_count, col_count, col_widths, truncated = \
        compute_optimal_layout(strings)

      # Slice the strings into rows.
      rows = Array.new(row_count){[]}
      col_index = 0
      strings.each_slice(row_count) do |column|
        column_width = col_widths[col_index]
        column.each_index do |i|
          string = column[i]

          rows[i] << string

          if col_index < col_count - 1
            # Add spacer to the width of the column
            rows[i] << (" " * (column_width - string.length))
            rows[i] << @@COLUMN_SEPARATOR
          end
        end

        col_index += 1
        break if col_index >= col_count
      end

      print_rows(rows, truncated)
    end

    def close
      # Only wipe the buffer if we're *sure* it's the explorer.
      if Window.select @window and \
         $curbuf == @buffer and \
         $curbuf.name =~ /#{Regexp.escape(@title)}$/
          VIM::command "bwipeout!"
          @window = nil
          @buffer = nil
      end
    end

    def self.max_height
      stored_height = $curwin.height
      $curwin.height = 99999  # ha
      highest_allowable = $curwin.height
      $curwin.height = stored_height
      highest_allowable
    end

    def self.max_width
      VIM::columns()
    end

  private

    def compute_optimal_layout(strings)
      # Compute optimal row count and corresponding column count.
      # The displayer attempts to fit `strings' on as few rows as
      # possible.

      max_width = Displayer.max_width()
      displayable_string_upper_bound = compute_displayable_upper_bound(strings)

      # Determine optimal row count.
      optimal_row_count, truncated = \
        if strings.length > displayable_string_upper_bound
          # Use all available rows and truncate results.
          # The -1 is for the truncation indicator.
          [Displayer.max_height - 1, true]
        else
          single_row_width = \
            strings.inject(0) { |len, s|
              len + @@COLUMN_SEPARATOR.length + s.length
            }
          if single_row_width <= max_width
            # All fits on a single row
            [1, false]
          else
            compute_optimal_row_count(strings)
          end
        end

      # Compute column_count and column_widths.
      column_count = 0
      column_widths = []
      total_width = 0
      strings.each_slice(optimal_row_count) do |column|
        column_width = column.max { |a, b| a.length <=> b.length }.length
        total_width += column_width

        break if total_width > max_width

        column_count += 1
        column_widths << column_width
        total_width += @@COLUMN_SEPARATOR.length
      end

      [optimal_row_count, column_count, column_widths, truncated]
    end

    def print_rows(rows, truncated)
      unlock_and_clear()

      # Grow/shrink the window as needed
      $curwin.height = rows.length + (truncated ? 1 : 0)

      # Print the rows.
      rows.each_index do |i|
        $curwin.cursor = [i+1, 1]
        $curbuf.append(i, rows[i].join(''))
      end

      # Print a TRUNCATED indicator, if needed.
      if truncated
        $curbuf.append($curbuf.count - 1, \
                       @@TRUNCATED_STRING.center($curwin.width, " "))
      end

      # Stretch the last line to the length of the window with whitespace so
      # that we can "hide" the cursor in the corner.
      last_line = $curbuf[$curbuf.count - 1]
      last_line << (" " * ($curwin.width - last_line.length))
      $curbuf[$curbuf.count - 1] = last_line

      # There's a blank line at the end of the buffer because of how
      # VIM::Buffer.append works.
      $curbuf.delete $curbuf.count
      lock()
    end

    def print_no_entries
      unlock_and_clear()
      $curwin.height = 1
      $curbuf[1] = @@NO_MATCHES_STRING.center($curwin.width, " ")
      lock()
    end

    def unlock_and_clear
      VIM::command "setlocal modifiable"

      # Clear the explorer (black hole register)
      VIM::command "silent %d _"
    end

    def lock
      VIM::command "setlocal nomodifiable"

      # Hide the cursor
      VIM::command "normal! Gg$"
    end

    def compute_displayable_upper_bound(strings)
      # Compute an upper-bound on the number of displayable matches.
      # Basically: find the length of the longest string, then keep
      # adding shortest strings until we pass the width of the Vim
      # window.  This is the maximum possible column-count assuming
      # all strings can fit.  Then multiply by the number of rows.

      sorted_by_shortest = strings.sort { |x, y| x.length <=> y.length }
      longest_length = sorted_by_shortest.pop.length

      row_width = longest_length + @@COLUMN_SEPARATOR.length

      max_width = Displayer.max_width()
      column_count = 1

      sorted_by_shortest.each do |str|
        row_width += str.length
        if row_width > max_width
          break
        end

        column_count += 1
        row_width += @@COLUMN_SEPARATOR.length
      end

      column_count * Displayer.max_height()
    end

    def compute_optimal_row_count(strings)
      max_width = Displayer.max_width
      max_height = Displayer.max_height

      # STEVE faster to allocate new hash?
      @col_range_widths.clear()

      # Binary search; find the lowest number of rows at which we
      # can fit all the strings.

      # We've already failed for a single row, so start at two.
      lower = 1  # (1 = 2 - 1)
      upper = max_height + 1
      while lower + 1 != upper
        row_count = (lower + upper) / 2   # Mid-point

        col_start_index = 0
        col_end_index = row_count - 1
        total_width = 0

        while col_end_index < strings.length
          total_width += \
            compute_column_width(col_start_index..col_end_index, strings)

          # STEVE early exit
          if total_width > max_width
            # STEVE change to max_fixnum
            total_width += @@COLUMN_SEPARATOR.length
            break
          end

          total_width += @@COLUMN_SEPARATOR.length

          col_start_index += row_count
          col_end_index += row_count

          if col_end_index >= strings.length and \
             col_start_index < strings.length
            # Remainder; last iteration will not be a full column.
            col_end_index = strings.length - 1
          end
        end

        # The final column doesn't need a separator.
        total_width -= @@COLUMN_SEPARATOR.length

        if total_width <= max_width
          # This row count fits.
          upper = row_count
        else
          # This row count doesn't fit.
          lower = row_count
        end
      end

      if upper > max_height
        # No row count can accomodate all strings; have to truncate.
        # (-1 for the truncate indicator)
        [max_height - 1, true]
      else
        [upper, false]
      end
    end

    def compute_column_width(range, strings)

      if (range.first == range.last)
        return strings[range.first].length
      end

      width = @col_range_widths[range]

      if width.nil?
        # Recurse for each half of the range.
        split_point = range.first + ((range.last - range.first) >> 1)

        first_half = compute_column_width(range.first..split_point, strings)
        second_half = compute_column_width(split_point+1..range.last, strings)

        width = [first_half, second_half].max
        @col_range_widths[range] = width
      end

      width
    end
end
end

