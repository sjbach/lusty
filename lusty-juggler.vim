"    Copyright: Copyright (C) 2008-2010 Stephen Bach
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               lusty-juggler.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
"
" Name Of File: lusty-juggler.vim
"  Description: Dynamic Buffer Switcher Vim Plugin
"   Maintainer: Stephen Bach <this-file@sjbach.com>
" Contributors: Juan Frias, Bartosz Leper
"
" Release Date: March 4, 2010
"      Version: 1.1.3
"
"        Usage: To launch the juggler:
"
"                 <Leader>lj
"                 or
"                 <Leader>lg
"
"               You can also use this command:
"
"                 ":LustyJuggler"
"
"               (Personally, I map this to ,g)
"
"               When the juggler launches, the command bar at bottom is
"               replaced with a new bar showing the names of your currently
"               opened buffers in most-recently-used order.
"
"               The buffer names are mapped to these keys:
"
"                   1st|2nd|3rd|4th|5th|6th|7th|8th|9th|10th
"                   ----------------------------------------
"                   a   s   d   f   g   h   j   k   l   ;
"                   1   2   3   4   5   6   7   8   9   0
"
"               So if you type "f" or "4", the fourth buffer name will be
"               highlighted and the bar will shift to center it as necessary
"               (and show more of the buffer names on the right).
"
"               If you want to switch to that buffer, press "f" or "4" again
"               or press "<ENTER>".  Alternatively, press one of the other
"               mapped keys to highlight another buffer.
"
"               To display the key before the name of the buffer, add one of
"               the following lines to your .vimrc:
"
"                 let g:LustyJugglerShowKeys = 'a'   (for alpha characters)
"                 let g:LustyJugglerShowKeys = 1     (for digits)
"
"               To cancel the juggler, press any of "q", "<ESC>", "<C-c",
"               "<BS>", "<Del>", or "<C-h>".
"
"
"        Bonus: This plugin also includes the following command, which will
"               immediately switch to your previously used buffer:
"
"                 ":JugglePrevious"
"               
"               This is similar to the :b# command, but accounts for the
"               common situation where your previously used buffer (#) has
"               been killed and is thus inaccessible.  In that case, it will
"               instead switch to the buffer used previous to the killed
"               buffer (and on down the line).
"               
"
" Install Details:
"
" Copy this file into your $HOME/.vim/plugin directory so that it will be
" sourced on startup automatically.
"
" Note! This plugin requires Vim be compiled with Ruby interpretation.  If you
" don't know if your build of Vim has this functionality, you can check by
" running "vim --version" from the command line and looking for "+ruby".
" Alternatively, just try sourcing this script.
"
" If your version of Vim does not have "+ruby" but you would still like to
" use this plugin, you can fix it.  See the "Check for Ruby functionality"
" comment below for instructions.
"
" If you are using the same Vim configuration and plugins for multiple
" machines, some of which have Ruby and some of which don't, you may want to
" turn off the "Sorry, LustyJuggler requires ruby" warning.  You can do so
" like this (in .vimrc):
"
"   let g:LustyJugglerSuppressRubyWarning = 1
"
" GetLatestVimScripts: 2050 1 :AutoInstall: lusty-juggler.vim
"
" TODO:
" - save and restore mappings
" - Add TAB recognition back.
" - Add option to open buffer immediately when mapping is pressed (but not
"   release the juggler until the confirmation press).
" - Have the delimiter character settable.
"   - have colours settable?

" Exit quickly when already loaded.
if exists("g:loaded_lustyjuggler")
  finish
endif

" Check for Ruby functionality.
if !has("ruby")
  if !exists("g:LustyExplorerSuppressRubyWarning") ||
      \ g:LustyExplorerSuppressRubyWarning == "0"
  if !exists("g:LustyJugglerSuppressRubyWarning") ||
      \ g:LustyJugglerSuppressRubyWarning == "0" 
    echohl ErrorMsg
    echon "Sorry, LustyJuggler requires ruby.  "
    echon "Here are some tips for adding it:\n"

    echo "Debian / Ubuntu:"
    echo "    # apt-get install vim-ruby\n"

    echo "Fedora:"
    echo "    # yum install vim-enhanced\n"

    echo "Gentoo:"
    echo "    # USE=\"ruby\" emerge vim\n"

    echo "FreeBSD:"
    echo "    # pkg_add -r vim+ruby\n"

    echo "Windows:"
    echo "    1. Download and install Ruby from here:"
    echo "       http://www.ruby-lang.org/"
    echo "    2. Install a Vim binary with Ruby support:"
    echo "       http://segfault.hasno.info/vim/gvim72.zip\n"

    echo "Manually (including Cygwin):"
    echo "    1. Install Ruby."
    echo "    2. Download the Vim source package (say, vim-7.0.tar.bz2)"
    echo "    3. Build and install:"
    echo "         # tar -xvjf vim-7.0.tar.bz2"
    echo "         # ./configure --enable-rubyinterp"
    echo "         # make && make install\n"

    echo "(If you just wish to stifle this message, set the following option:"
    echo "  let g:LustyJugglerSuppressRubyWarning = 1)"
    echohl none
  endif
  endif
  finish
endif

let g:loaded_lustyjuggler = "yep"

" Commands.
if !exists(":LustyJuggler")
  command LustyJuggler :call <SID>LustyJugglerStart()
  command JugglePrevious :call <SID>JugglePreviousRun()
endif

" Default mappings.
nmap <silent> <Leader>lg :LustyJuggler<CR>
nmap <silent> <Leader>lj :LustyJuggler<CR>

" Vim-to-ruby function calls.
function! s:LustyJugglerStart()
  ruby $lusty_juggler.run
endfunction

function! LustyJugglerKeyPressed(code_arg)
  ruby $lusty_juggler.key_pressed
endfunction

function! LustyJugglerCancel()
  ruby $lusty_juggler.cleanup
endfunction

function! s:JugglePreviousRun()
  ruby juggle_previous()
endfunction

" Setup the autocommands that handle buffer MRU ordering.
augroup LustyJuggler
  autocmd!
  autocmd BufEnter * ruby $buffer_stack.push
  autocmd BufDelete * ruby $buffer_stack.pop
  autocmd BufWipeout * ruby $buffer_stack.pop
augroup End

ruby << EOF

require 'pathname'

class AssertionError < StandardError
end

def assert(condition, message = 'assertion failure')
  raise AssertionError.new(message) unless condition
end

module VIM
  def self.zero?(var)
    # In Vim 7.2 and older, VIM::evaluate returns Strings for boolean
    # expressions; in later versions, Fixnums.
    case var
    when String
      var == "0"
    when Fixnum
      var == 0
    else
      assert(false, "unexpected type: #{var.class}")
    end
  end

  def self.nonzero?(var)
    not(self.zero? var)
  end

  def self.exists?(s)
    self.nonzero? eva("exists('#{s}')")
  end
end


class LustyJuggler
  private
    @@KEYS = { "a" => 1,
               "s" => 2,
               "d" => 3,
               "f" => 4,
               "g" => 5,
               "h" => 6,
               "j" => 7,
               "k" => 8,
               "l" => 9,
               ";" => 10,
               "1" => 1,
               "2" => 2,
               "3" => 3,
               "4" => 4,
               "5" => 5,
               "6" => 6,
               "7" => 7,
               "8" => 8,
               "9" => 9,
               "0" => 10 }

  public
    def initialize
      @running = false
      @last_pressed = nil
      @name_bar = NameBar.new
    end

    def run
      return if @running

      if $buffer_stack.length <= 1
        pretty_msg("PreProc", "No other buffers")
        return
      end

      @running = true

      # Need to zero the timeout length or pressing 'g' will hang.
      @ruler = VIM::nonzero? eva("&ruler")
      @showcmd = VIM::nonzero? eva("&showcmd")
      @showmode = VIM::nonzero? eva("&showmode")
      @timeoutlen = eva("&timeoutlen")
      set 'timeoutlen=0'
      set 'noruler'
      set 'noshowcmd'
      set 'noshowmode'

      # Selection keys.
      @@KEYS.keys.each do |c|
        exe "noremap <silent> #{c} :call LustyJugglerKeyPressed('#{c}')<CR>"
      end
      # Can't use '<CR>' as an argument to :call func for some reason.
      exe "noremap <silent> <CR>  :call LustyJugglerKeyPressed('ENTER')<CR>"
      #exe "noremap <silent> <Tab>  :call LustyJugglerKeyPressed('TAB')<CR>"

      # Cancel keys.
      exe "noremap <silent> q     :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <Esc> :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <C-c> :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <BS>  :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <Del> :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <C-h> :call LustyJugglerCancel()<CR>"

      print_buffer_list()
    end

    def key_pressed()
      c = eva("a:code_arg")

      if (c == @last_pressed) or \
         (@last_pressed and c == 'ENTER')
        choose(@@KEYS[@last_pressed])
        cleanup()
      else
        print_buffer_list(@@KEYS[c])
        @last_pressed = c
      end
    end

    # Restore settings, mostly.
    def cleanup
      @last_pressed = nil

      set "timeoutlen=#{@timeoutlen}"
      set "ruler" if @ruler
      set "showcmd" if @showcmd
      set "showmode" if @showmode

      @@KEYS.keys.each do |c|
        exe "unmap <silent> #{c}"
      end
      exe "unmap <silent> <CR>"
      #exe "unmap <silent> <Tab>"

      exe "unmap <silent> q"
      exe "unmap <silent> <Esc>"
      exe "unmap <silent> <C-c>"
      exe "unmap <silent> <BS>"
      exe "unmap <silent> <Del>"
      exe "unmap <silent> <C-h>"

      @running = false
      msg ""
    end

  private
    def print_buffer_list(highlighted_entry=0)
      # If the user pressed a key higher than the number of open buffers,
      # highlight the highest (see also BufferStack.num_at_pos()).
      @name_bar.active = [highlighted_entry, $buffer_stack.length].min

      @name_bar.print
    end

    def choose(i)
      buf = $buffer_stack.num_at_pos(i)
      exe "b #{buf}"
    end
end


# An item (delimiter/separator or buffer name) on the NameBar.
class BarItem
  def initialize(str, color)
    @str = str
    @color = color
  end

  def length
    @str.length
  end

  def pretty_print_input
    [@color, @str]
  end

  def [](*rest)
    return BarItem.new(@str[*rest], @color)
  end

  def self.full_length(array)
    if array
      array.inject(0) { |sum, el| sum + el.length }
    else
      0
    end
  end
end

class Buffer < BarItem
  def initialize(str, active)
    @str = str
    @active = active
    destructure()
  end

  def [](*rest)
    return Buffer.new(@str[*rest], @active)
  end

  def pretty_print_input
    @array
  end

  private
    @@BUFFER_COLOR = "PreProc"
    #@@BUFFER_COLOR = "None"
    @@DIR_COLOR = "Directory"
    @@SLASH_COLOR = "Function"
    @@ACTIVE_COLOR = "Question"

    # Breakdown the string to colourize each part.
    def destructure
      if @active
        buf_color = @@ACTIVE_COLOR
        dir_color = @@ACTIVE_COLOR
        slash_color = @@ACTIVE_COLOR
      else
        buf_color = @@BUFFER_COLOR
        dir_color = @@DIR_COLOR
        slash_color = @@SLASH_COLOR
      end

      pieces = @str.split(File::SEPARATOR, -1) 

      @array = []
      @array << dir_color
      @array << pieces.shift
      pieces.each { |piece|
        @array << slash_color
        @array << File::SEPARATOR
        @array << dir_color
        @array << piece
      }

      # Last piece is the actual name.
      @array[-2] = buf_color
    end
end

class Separator < BarItem
  public
    def initialize
      super(@@TEXT, @@COLOR)
    end

  private
    @@TEXT = "|"
    #@@COLOR = "NonText"
    @@COLOR = "None"
end

class LeftContinuer < BarItem
  public
    def initialize
      super(@@TEXT, @@COLOR)
    end

    def self.length
      @@TEXT.length
    end

  private
    @@TEXT = "<"
    @@COLOR = "NonText"
end

class RightContinuer < BarItem
  public
    def initialize
      super(@@TEXT, @@COLOR)
    end

    def self.length
      @@TEXT.length
    end

  private
    @@TEXT = ">"
    @@COLOR = "NonText"
end


# A one-line display of the open buffers, appearing in the command display.
class NameBar
  public
    def initialize
      @active = nil
    end

    def active=(i)
      # Correct for zero-based array.
      @active = (i > 0) ? i - 1 : nil
    end

    def print
      items = create_items()
      clipped = clip(items)
      NameBar.do_pretty_print(clipped)
    end

  private
    @@LETTERS = ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";"]


    def create_items
      names = $buffer_stack.names

      items = names.inject([]) { |array, name|
        key = if VIM::exists?("g:LustyJugglerShowKeys")
                case eva("g:LustyJugglerShowKeys").to_s
                when /[[:alpha:]]/
                  @@LETTERS[array.size / 2] + ":"
                when /[[:digit:]]/
                  "#{((array.size / 2) + 1) % 10}:"
                else
                  ""
                end
              else
                ""
              end

        array << Buffer.new("#{key}#{name}",
                            (@active and name == names[@active]))
        array << Separator.new
      }
      items.pop   # Remove last separator.

      # Account for the separators.
      @active and @active = [@active * 2, (items.length - 1)].min

      return items
    end

    # Clip the given array of items to the available display width.
    def clip(items)
      @active = 0 if @active.nil?

      half_displayable_len = columns() / 2

      # The active buffer is excluded since it's basically split between
      # the sides.
      left_len = BarItem.full_length items[0, @active - 1]
      right_len = BarItem.full_length items[@active + 1, items.length - 1]

      right_justify = (left_len > half_displayable_len) and \
                      (right_len < half_displayable_len)

      active_str_half_len = (items[@active].length / 2) + \
                            (items[@active].length % 2 == 0 ? 0 : 1)

      if right_justify
        # Right justify the bar.
        first_layout = self.method :layout_right
        second_layout = self.method :layout_left
        first_adjustment = active_str_half_len
        second_adjustment = -active_str_half_len
      else
        # Left justify (sort-of more likely).
        first_layout = self.method :layout_left
        second_layout = self.method :layout_right
        first_adjustment = -active_str_half_len
        second_adjustment = active_str_half_len
      end

      # Layout the first side.
      allocation = half_displayable_len + first_adjustment
      first_side, remainder = first_layout.call(items, allocation)

      # Then layout the second side, also grabbing any unused space.
      allocation = half_displayable_len + \
                   second_adjustment + \
                   remainder
      second_side, remainder = second_layout.call(items, allocation)

      if right_justify
        second_side + first_side
      else
        first_side + second_side
      end
    end

    # Clip the given array of items to the given space, counting downwards.
    def layout_left(items, space)
      trimmed = []

      i = @active - 1
      while i >= 0
        m = items[i]
        if space > m.length
          trimmed << m
          space -= m.length
        elsif space > 0
          trimmed << m[m.length - (space - LeftContinuer.length), \
                       space - LeftContinuer.length]
          trimmed << LeftContinuer.new
          space = 0
        else
          break
        end
        i -= 1
      end

      return trimmed.reverse, space
    end

    # Clip the given array of items to the given space, counting upwards.
    def layout_right(items, space)
      trimmed = []

      i = @active
      while i < items.length
        m = items[i]
        if space > m.length
          trimmed << m
          space -= m.length
        elsif space > 0
          trimmed << m[0, space - RightContinuer.length]
          trimmed << RightContinuer.new
          space = 0
        else
          break
        end
        i += 1
      end

      return trimmed, space
    end

    def NameBar.do_pretty_print(items)
      args = items.inject([]) { |array, item|
        array = array + item.pretty_print_input
      }

      pretty_msg *args
    end
end


# Maintain MRU ordering.
# A little bit different than the LustyExplorer version -- probably they
# should be unified.
class BufferStack
  public
    def initialize
      @stack = []

      (0..VIM::Buffer.count-1).each do |i|
        @stack << VIM::Buffer[i].number
      end
    end

    def names
      # Get the last 10 buffer names by MRU.  Show only as much of
      # the name as necessary to differentiate between buffers of
      # the same name.
      cull!
      names = @stack.collect { |i| buf_name(i) }.reverse[0,10]
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
      number = eva 'bufnr(expand("<afile>"))'
      @stack.delete number
    end

  private
    def cull!
      # Remove empty buffers.
      @stack.delete_if { |x| VIM::zero? eva("bufexists(#{x})") }
    end

    def buf_name(i)
      eva("bufname(#{i})")
    end

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


# Switch to the previous buffer (the one you were using before the current
# one).  This is basically a smarter replacement for :b#, accounting for
# the situation where your previous buffer no longer exists.
def juggle_previous
  buf = $buffer_stack.num_at_pos(2)
  exe "b #{buf}"
end

# Simple mappings to decrease typing.
def exe(s)
  VIM.command s
end

def eva(s)
  VIM.evaluate s
end

def set(s)
  VIM.set_option s
end

def msg(s)
  VIM.message s
end

def columns
  # Vim gives the annoying "Press ENTER to continue" message if we use the
  # full width.
  eva("&columns").to_i - 1
end

def pretty_msg(*rest)
  return if rest.length == 0
  return if rest.length % 2 != 0

  #exe "redraw"

  i = 0
  while i < rest.length do
    exe "echohl #{rest[i]}"
    exe "echon '#{rest[i+1]}'"
    i += 2
  end

  exe 'echohl None'
end


$lusty_juggler = LustyJuggler.new
$buffer_stack = BufferStack.new


EOF

