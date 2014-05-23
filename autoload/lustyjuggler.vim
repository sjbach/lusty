" Vim-to-ruby function calls.
function! lustyjuggler#LustyJugglerStart()
  ruby LustyJ::profile() { $lusty_juggler.run }
endfunction

function! s:LustyJugglerKeyPressed(code_arg)
  ruby LustyJ::profile() { $lusty_juggler.key_pressed }
endfunction

function! s:LustyJugglerCancel()
  ruby LustyJ::profile() { $lusty_juggler.cleanup }
endfunction

function! lustyjuggler#LustyJugglePreviousRun()
  ruby LustyJ::profile() { $lj_buffer_stack.juggle_previous }
endfunction

" Setup the autocommands that handle buffer MRU ordering.
augroup LustyJuggler
  autocmd!
  autocmd BufAdd,BufEnter * ruby LustyJ::profile() { $lj_buffer_stack.push }
  autocmd BufDelete * ruby LustyJ::profile() { $lj_buffer_stack.pop }
  autocmd BufWipeout * ruby LustyJ::profile() { $lj_buffer_stack.pop }
augroup End

" Used to work around a flaw in Vim's ruby bindings.
let s:maparg_holder = 0
let s:maparg_dict_holder = { }

ruby << EOF

require 'pathname'

$LUSTY_PROFILING = false

if $LUSTY_PROFILING
  require 'rubygems'
  require 'ruby-prof'
end


module VIM

  unless const_defined? "MOST_POSITIVE_INTEGER"
    MOST_POSITIVE_INTEGER = 2**(32 - 1) - 2  # Vim ints are signed 32-bit.
  end

  def self.zero?(var)
    # In Vim 7.2 and older, VIM::evaluate returns Strings for boolean
    # expressions; in later versions, Fixnums.
    case var
    when String
      var == "0"
    when Fixnum
      var == 0
    else
      LustyJ::assert(false, "unexpected type: #{var.class}")
    end
  end

  def self.nonzero?(var)
    not zero?(var)
  end

  def self.evaluate_bool(var)
    nonzero? evaluate(var)
  end

  def self.exists?(s)
    nonzero? evaluate("exists('#{s}')")
  end

  def self.has_syntax?
    nonzero? evaluate('has("syntax")')
  end

  def self.has_ext_maparg?
    # The 'dict' parameter to mapargs() was introduced in Vim 7.3.32
    nonzero? evaluate('v:version > 703 || (v:version == 703 && has("patch32"))')
  end

  def self.columns
    evaluate("&columns").to_i
  end

  def self.lines
    evaluate("&lines").to_i
  end

  def self.getcwd
    evaluate("getcwd()")
  end

  def self.bufname(i)
    if evaluate_bool("empty(bufname(#{i}))")
      "<Unknown #{i}>"
    else
      evaluate("bufname(#{i})")
    end
  end

  def self.single_quote_escape(s)
    # Everything in a Vim single-quoted string is literal, except single
    # quotes.  Single quotes are escaped by doubling them.
    s.gsub("'", "''")
  end

  def self.regex_escape(s)
    s.gsub(/[\]\[.~"^$\\*]/,'\\\\\0')
  end

  class Buffer
    def modified?
      VIM::nonzero? VIM::evaluate("getbufvar(#{number()}, '&modified')")
    end

    def listed?
      VIM::nonzero? VIM::evaluate("getbufvar(#{number()}, '&buflisted')")
    end

    def self.obj_for_bufnr(n)
      # There's gotta be a better way to do this...
      (0..VIM::Buffer.count-1).each do |i|
        obj = VIM::Buffer[i]
        return obj if obj.number == n
      end

      return nil
    end
  end

  # Print with colours
  def self.pretty_msg(*rest)
    return if rest.length == 0
    return if rest.length % 2 != 0

    command "redraw"  # see :help echo-redraw
    i = 0
    while i < rest.length do
      command "echohl #{rest[i]}"
      command "echon '#{rest[i+1]}'"
      i += 2
    end

    command 'echohl None'
  end
end

# Hack for wide CJK characters.
if VIM::exists?("*strwidth")
  module VIM
    def self.strwidth(s)
      # strwidth() is defined in Vim 7.3.
      evaluate("strwidth('#{single_quote_escape(s)}')").to_i
    end
  end
else
  module VIM
    def self.strwidth(s)
      s.length
    end
  end
end

if VIM::exists?("*fnameescape")
  module VIM
    def self.filename_escape(s)
      # Escape slashes, open square braces, spaces, sharps, double
      # quotes and percent signs, and remove leading ./ for files in
      # pwd.
      single_quote_escaped = single_quote_escape(s)
      evaluate("fnameescape('#{single_quote_escaped}')").sub(/^\.\//,"")
    end
  end
else
  module VIM
    def self.filename_escape(s)
      # Escape slashes, open square braces, spaces, sharps, double
      # quotes and percent signs, and remove leading ./ for files in
      # pwd.
      s.gsub(/\\/, '\\\\\\').gsub(/[\[ #"%]/, '\\\\\0').sub(/^\.\//,"")
    end
  end
end


# Utility functions.
module LustyJ

  unless const_defined? "MOST_POSITIVE_FIXNUM"
    # Per <https://github.com/sjbach/lusty/issues/80>, this computation causes
    # an error in MacVim.  Since in usage the value doesn't matter too much
    # as long as it's high, overriding.
    #MOST_POSITIVE_FIXNUM = 2**(0.size * 8 -2) -1
    MOST_POSITIVE_FIXNUM = 2**(16 - 1) - 2
  end

  def self.simplify_path(s)
    s = s.gsub(/\/+/, '/')  # Remove redundant '/' characters
    begin
      if s[0] == ?~
        # Tilde expansion - First expand the ~ part (e.g. '~' or '~steve')
        # and then append the rest of the path.  We can't just call
        # expand_path() or it'll throw on bad paths.
        s = File.expand_path(s.sub(/\/.*/,'')) + \
            s.sub(/^[^\/]+/,'')
      end

      if s == '/'
        # Special-case root so we don't add superfluous '/' characters,
        # as this can make Cygwin choke.
        s
      elsif ends_with?(s, File::SEPARATOR)
        File.expand_path(s) + File::SEPARATOR
      else
        dirname_expanded = File.expand_path(File.dirname(s))
        if dirname_expanded == '/'
          dirname_expanded + File.basename(s)
        else
          dirname_expanded + File::SEPARATOR + File.basename(s)
        end
      end
    rescue ArgumentError
      s
    end
  end

  def self.longest_common_prefix(paths)
    prefix = paths[0]
    paths.each do |path|
      for i in 0...prefix.length
        if path.length <= i or prefix[i] != path[i]
          prefix = prefix[0...i]
          prefix = prefix[0..(prefix.rindex('/') or -1)]
          break
        end
      end
    end

    prefix
  end

  def self.ready_for_read?(io)
    if io.respond_to? :ready?
      ready?
    else
      result = IO.select([io], nil, nil, 0)
      result && (result.first.first == io)
    end
  end

  def self.ends_with?(s1, s2)
    tail = s1[-s2.length, s2.length]
    tail == s2
  end

  def self.starts_with?(s1, s2)
    head = s1[0, s2.length]
    head == s2
  end

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


module LustyJ
class BaseLustyJuggler
  public
    def initialize
      @running = false
      @last_pressed = nil
      @name_bar = NameBar.new(alpha_buffer_keys)
      @ALPHA_BUFFER_KEYS = Hash.new
      alpha_buffer_keys.each_with_index {|x, i| @ALPHA_BUFFER_KEYS[x] = i + 1}
      @NUMERIC_BUFFER_KEYS = {
        "1" => 1,
        "2" => 2,
        "3" => 3,
        "4" => 4,
        "5" => 5,
        "6" => 6,
        "7" => 7,
        "8" => 8,
        "9" => 9,
        "0" => 10,
        "10" => 10
      }
      @BUFFER_KEYS = @ALPHA_BUFFER_KEYS.merge(@NUMERIC_BUFFER_KEYS)
      @KEYPRESS_KEYS = {
        # Can't use '<CR>' as an argument to :call func for some reason.
        "<CR>" => "ENTER",
        "<Tab>" => "TAB",

        # Split opener keys
        "v" => "v",
        "b" => "b",

        # Left and Right keys
        "<Esc>OD" => "Left",
        "<Esc>OC" => "Right",
        "<Left>" => "Left",
        "<Right>" => "Right",
      }
      @KEYPRESS_MAPPINGS = @BUFFER_KEYS.merge(@KEYPRESS_KEYS)
    end

    def cancel_mappings
      @cancel_mappings ||= (default_cancel_mappings - alpha_buffer_keys)
    end

    def run
      if $lj_buffer_stack.length <= 1
        VIM::pretty_msg("PreProc", "No other buffers")
        return
      end

      # If already running, highlight next buffer
      if @running and LustyJuggler::alt_tab_mode_active?
        @last_pressed = (@last_pressed % $lj_buffer_stack.length) + 1;
        print_buffer_list(@last_pressed)
        return
      end

      return if @running
      @running = true

      # Need to zero the timeout length or pressing 'g' will hang.
      @timeoutlen = VIM::evaluate("&timeoutlen")
      @ruler = VIM::evaluate_bool("&ruler")
      @showcmd = VIM::evaluate_bool("&showcmd")
      @showmode = VIM::evaluate_bool("&showmode")
      VIM::set_option 'timeoutlen=0'
      VIM::set_option 'noruler'
      VIM::set_option 'noshowcmd'
      VIM::set_option 'noshowmode'

      @key_mappings_map = Hash.new { |hash, k| hash[k] = [] }

      # Selection keys.
      @KEYPRESS_MAPPINGS.each_pair do |c, v|
        map_key(c, ":call <SID>LustyJugglerKeyPressed('#{v}')<CR>")
      end

      # Cancel keys.
      cancel_mappings.each do |c|
        map_key(c, ":call <SID>LustyJugglerCancel()<CR>")
      end

      @last_pressed = 2 if LustyJuggler::alt_tab_mode_active?
      print_buffer_list(@last_pressed)
    end

    def key_pressed()
      c = VIM::evaluate("a:code_arg")

      if @last_pressed.nil? and c == 'ENTER'
        cleanup()
      elsif @last_pressed and (@BUFFER_KEYS[c] == @last_pressed or c == 'ENTER')
        choose(@last_pressed)
        cleanup()
      elsif @last_pressed and %w(v b).include?(c)
        c=='v' ? vsplit(@last_pressed) : hsplit(@last_pressed)
        cleanup()
      elsif c == 'Left'
        @last_pressed = (@last_pressed.nil?) ? 0 : (@last_pressed)
        @last_pressed = (@last_pressed - 1) < 1 ? $lj_buffer_stack.length : (@last_pressed - 1)
        print_buffer_list(@last_pressed)
      elsif c == 'Right'
        @last_pressed = (@last_pressed.nil?) ? 0 : (@last_pressed)
        @last_pressed = (@last_pressed + 1) > $lj_buffer_stack.length ? 1 : (@last_pressed + 1)
        print_buffer_list(@last_pressed)
      else
        @last_pressed = @BUFFER_KEYS[c]
        print_buffer_list(@last_pressed)
      end
    end

    # Restore settings, mostly.
    def cleanup
      @last_pressed = nil

      VIM::set_option "timeoutlen=#{@timeoutlen}"
      VIM::set_option "ruler" if @ruler
      VIM::set_option "showcmd" if @showcmd
      VIM::set_option "showmode" if @showmode

      @KEYPRESS_MAPPINGS.keys.each do |c|
        unmap_key(c)
      end
      cancel_mappings.each do |c|
        unmap_key(c)
      end

      @running = false
      VIM::message ' '
      VIM::command 'redraw'  # Prevents "Press ENTER to continue" message.
    end

  private
    def self.alt_tab_mode_active?
       return (VIM::exists?("g:LustyJugglerAltTabMode") and
               VIM::evaluate("g:LustyJugglerAltTabMode").to_i != 0)
    end

    def print_buffer_list(highlighted_entry = nil)
      # If the user pressed a key higher than the number of open buffers,
      # highlight the highest (see also BufferStack.num_at_pos()).

      @name_bar.selected_buffer = \
        if highlighted_entry
          # Correct for zero-based array.
          [highlighted_entry, $lj_buffer_stack.length].min - 1
        else
          nil
        end

      @name_bar.print
    end

    def choose(i)
      buf = $lj_buffer_stack.num_at_pos(i)
      VIM::command "b #{buf}"
    end
    
    def vsplit(i)
      buf = $lj_buffer_stack.num_at_pos(i)
      VIM::command "vert sb #{buf}"
    end
    
    def hsplit(i)
      buf = $lj_buffer_stack.num_at_pos(i)
      VIM::command "sb #{buf}"
    end

    def map_key(key, action)
      ['n','s','x','o','i','c','l'].each do |mode|
        VIM::command "let s:maparg_holder = maparg('#{key}', '#{mode}')"
        if VIM::evaluate_bool("s:maparg_holder != ''")
          orig_rhs = VIM::evaluate("s:maparg_holder")
          if VIM::has_ext_maparg?
            VIM::command "let s:maparg_dict_holder = maparg('#{key}', '#{mode}', 0, 1)"
            nore    = VIM::evaluate_bool("s:maparg_dict_holder['noremap']") ? 'nore'      : ''
            silent  = VIM::evaluate_bool("s:maparg_dict_holder['silent']")  ? ' <silent>' : ''
            expr    = VIM::evaluate_bool("s:maparg_dict_holder['expr']")    ? ' <expr>'   : ''
            buffer  = VIM::evaluate_bool("s:maparg_dict_holder['buffer']")  ? ' <buffer>' : ''
            restore_cmd = "#{mode}#{nore}map#{silent}#{expr}#{buffer} #{key} #{orig_rhs}"
          else
            nore = LustyJ::starts_with?(orig_rhs, '<Plug>') ? '' : 'nore'
            restore_cmd = "#{mode}#{nore}map <silent> #{key} #{orig_rhs}"
          end
          @key_mappings_map[key] << [ mode, restore_cmd ]
        end
        VIM::command "#{mode}noremap <silent> #{key} #{action}"
      end
    end

    def unmap_key(key)
      #first, unmap lusty_juggler's maps
      ['n','s','x','o','i','c','l'].each do |mode|
        VIM::command "#{mode}unmap <silent> #{key}"
      end

      if @key_mappings_map.has_key?(key)
        @key_mappings_map[key].each do |a|
          mode, restore_cmd = *a
          # for mappings that have on the rhs \|, the \ is somehow stripped
          restore_cmd.gsub!("|", "\\|")
          VIM::command restore_cmd
        end
      end
    end

    def default_cancel_mappings
      [
        "i",
        "I",
        "A",
        "c",
        "C",
        "o",
        "O",
        "S",
        "r",
        "R",
        "q",
        "<Esc>",
        "<C-c>",
        "<BS>",
        "<Del>",
        "<C-h>"
      ]
    end
  end

  class LustyJuggler < BaseLustyJuggler
    private
    def alpha_buffer_keys
      [
        "a",
        "s",
        "d",
        "f",
        "g",
        "h",
        "j",
        "k",
        "l",
        ";",
      ]
    end

  end

  class LustyJugglerDvorak < LustyJuggler
    private
      def alpha_buffer_keys
        [
          "a",
          "o",
          "e",
          "u",
          "i",
          "d",
          "h",
          "t",
          "n",
          "s"
        ]
      end
  end

  class LustyJugglerColemak < LustyJuggler
    private
      def alpha_buffer_keys
        [
          "a",
          "r",
          "s",
          "t",
          "d",
          "h",
          "n",
          "e",
          "i",
          "o",
        ]
      end
  end

  class LustyJugglerBepo < LustyJuggler
    private
    def alpha_buffer_keys
      [
        "a",
        "u",
        "i",
        "e",
        ",",
        "t",
        "s",
        "r",
        "n",
        "m",
      ]
    end
  end

  class LustyJugglerAzerty < LustyJuggler
    private
    def alpha_buffer_keys
      [
        "q",
        "s",
        "d",
        "f",
        "g",
        "j",
        "k",
        "l",
        "m",
        "ù",
      ]
    end
    end
end

# An item (delimiter/separator or buffer name) on the NameBar.
module LustyJ
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

class BufferItem < BarItem
  def initialize(str, highlighted)
    @str = str
    @highlighted = highlighted
    destructure()
  end

  def [](*rest)
    return BufferItem.new(@str[*rest], @highlighted)
  end

  def pretty_print_input
    @array
  end

  private
    @@BUFFER_COLOR = "PreProc"
    #@@BUFFER_COLOR = "None"
    @@DIR_COLOR = "Directory"
    @@SLASH_COLOR = "Function"
    @@HIGHLIGHTED_COLOR = "Question"

    # Breakdown the string to colourize each part.
    def destructure
      if @highlighted
        buf_color = @@HIGHLIGHTED_COLOR
        dir_color = @@HIGHLIGHTED_COLOR
        slash_color = @@HIGHLIGHTED_COLOR
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

class SeparatorItem < BarItem
  public
    def initialize
      super(@@TEXT, @@COLOR)
    end

  private
    @@TEXT = "|"
    #@@COLOR = "NonText"
    @@COLOR = "None"
end

class LeftContinuerItem < BarItem
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

class RightContinuerItem < BarItem
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

end


# A one-line display of the open buffers, appearing in the command display.
module LustyJ
class NameBar
  public
    def initialize(letters)
      @selected_buffer = nil
      @LETTERS = letters
    end

    attr_writer :selected_buffer

    def print
      items = create_items()

      selected_item = \
        if @selected_buffer
          # Account for the separators we've added.
          [@selected_buffer * 2, (items.length - 1)].min
        end

      clipped = clip(items, selected_item)
      NameBar.do_pretty_print(clipped)
    end


    def create_items
      names = $lj_buffer_stack.names(10)

      items = names.inject([]) { |array, name|
        key = if VIM::exists?("g:LustyJugglerShowKeys")
                case VIM::evaluate("g:LustyJugglerShowKeys").to_s
                when /[[:alpha:]]/
                  @LETTERS[array.size / 2] + ":"
                when /[[:digit:]]/
                  "#{((array.size / 2) + 1) % 10}:"
                else
                  ""
                end
              else
                ""
              end

        array << BufferItem.new("#{key}#{name}",
                            (@selected_buffer and \
                             name == names[@selected_buffer]))
        array << SeparatorItem.new
      }
      items.pop   # Remove last separator.

      return items
    end

    # Clip the given array of items to the available display width.
    def clip(items, selected)
      # This function is pretty hard to follow...

      # Note: Vim gives the annoying "Press ENTER to continue" message if we
      # use the full width.
      columns = VIM::columns() - 1

      if BarItem.full_length(items) <= columns
        return items
      end

      selected = 0 if selected.nil?
      half_displayable_len = columns / 2

      # The selected buffer is excluded since it's basically split between
      # the sides.
      left_len = BarItem.full_length items[0, selected - 1]
      right_len = BarItem.full_length items[selected + 1, items.length - 1]

      right_justify = (left_len > half_displayable_len) and \
                      (right_len < half_displayable_len)

      selected_str_half_len = (items[selected].length / 2) + \
                              (items[selected].length % 2 == 0 ? 0 : 1)

      if right_justify
        # Right justify the bar.
        first_layout = self.method :layout_right
        second_layout = self.method :layout_left
        first_adjustment = selected_str_half_len
        second_adjustment = -selected_str_half_len
      else
        # Left justify (sort-of more likely).
        first_layout = self.method :layout_left
        second_layout = self.method :layout_right
        first_adjustment = -selected_str_half_len
        second_adjustment = selected_str_half_len
      end

      # Layout the first side.
      allocation = half_displayable_len + first_adjustment
      first_side, remainder = first_layout.call(items,
                                                selected,
                                                allocation)

      # Then layout the second side, also grabbing any unused space.
      allocation = half_displayable_len + \
                   second_adjustment + \
                   remainder
      second_side, remainder = second_layout.call(items,
                                                  selected,
                                                  allocation)

      if right_justify
        second_side + first_side
      else
        first_side + second_side
      end
    end

    # Clip the given array of items to the given space, counting downwards.
    def layout_left(items, selected, space)
      trimmed = []

      i = selected - 1
      while i >= 0
        m = items[i]
        if space > m.length
          trimmed << m
          space -= m.length
        elsif space > 0
          trimmed << m[m.length - (space - LeftContinuerItem.length), \
                       space - LeftContinuerItem.length]
          trimmed << LeftContinuerItem.new
          space = 0
        else
          break
        end
        i -= 1
      end

      return trimmed.reverse, space
    end

    # Clip the given array of items to the given space, counting upwards.
    def layout_right(items, selected, space)
      trimmed = []

      i = selected
      while i < items.length
        m = items[i]
        if space > m.length
          trimmed << m
          space -= m.length
        elsif space > 0
          trimmed << m[0, space - RightContinuerItem.length]
          trimmed << RightContinuerItem.new
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

      VIM::pretty_msg *args
    end
end

end


# Maintain MRU ordering.
module LustyJ
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

    def names(n = :all)
      # Get the last n buffer names by MRU.  Show only as much of
      # the name as necessary to differentiate between buffers of
      # the same name.
      cull!
      names = @stack.collect { |i| VIM::bufname(i) }.reverse
      if n != :all
        names = names[0,n]
      end
      shorten_paths(names)
    end

    def numbers(n = :all)
      # Get the last n buffer numbers by MRU.
      cull!
      numbers = @stack.reverse
      if n == :all
        numbers
      else
        numbers[0,n]
      end
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
      buf_number = VIM::evaluate('expand("<abuf>")').to_i
      @stack.delete buf_number
      @stack << buf_number
    end

    def pop
      number = VIM::evaluate('bufnr(expand("<abuf>"))')
      @stack.delete number
    end

  private
    def cull!
      # Remove empty and unlisted buffers.
      @stack.delete_if { |x|
        not (VIM::evaluate_bool("bufexists(#{x})") and
             VIM::evaluate_bool("getbufvar(#{x}, '&buflisted')"))
      }
    end

    # NOTE: very similar to Entry::compute_buffer_entries()
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
          basename_to_prefix[k] = LustyJ::longest_common_prefix(names)
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
end

end



if VIM::exists?('g:LustyJugglerKeyboardLayout') and VIM::evaluate_bool('g:LustyJugglerKeyboardLayout == "dvorak"')
  $lusty_juggler = LustyJ::LustyJugglerDvorak.new
elsif VIM::exists?('g:LustyJugglerKeyboardLayout') and VIM::evaluate_bool('g:LustyJugglerKeyboardLayout == "colemak"')
  $lusty_juggler = LustyJ::LustyJugglerColemak.new
elsif VIM::exists?('g:LustyJugglerKeyboardLayout') and VIM::evaluate_bool('g:LustyJugglerKeyboardLayout == "bépo"')
	$lusty_juggler = LustyJ::LustyJugglerBepo.new
elsif VIM::exists?('g:LustyJugglerKeyboardLayout') and VIM::evaluate_bool('g:LustyJugglerKeyboardLayout == "azerty"')
	$lusty_juggler = LustyJ::LustyJugglerAzerty.new
else 
  $lusty_juggler = LustyJ::LustyJuggler.new
end
$lj_buffer_stack = LustyJ::BufferStack.new

EOF

" vim: set sts=2 sw=2:
