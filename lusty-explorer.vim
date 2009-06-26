"    Copyright: Copyright (C) 2007-2009 Stephen Bach
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               lusty-explorer.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
"
" Name Of File: lusty-explorer.vim
"  Description: Dynamic Filesystem and Buffer Explorer Vim Plugin
"  Maintainers: Stephen Bach <this-file@sjbach.com>
"               Matt Tolton <matt-lusty-explorer@tolton.com>
" Contributors: Raimon Grau, Sergey Popov, Yuichi Tateno, Bernhard Walle,
"               Rajendra Badapanda, cho45, Simo Salminen, Sami Samhuri,
"               Matt Tolton
"
" Release Date: June 8, 2009
"      Version: 2.1.0
"               Inspired by Viewglob, Emacs, and by Jeff Lanzarotta's Buffer
"               Explorer plugin.
"
"        Usage: To launch the explorers:
"
"                 <Leader>lf  - Opens the filesystem explorer.
"                 <Leader>lr  - Opens the filesystem explorer from the parent
"                               directory of the current file.
"                 <Leader>lb  - Opens the buffer explorer.
"
"               You can also use the commands:
"
"                 ":FilesystemExplorer"
"                 ":FilesystemExplorerFromHere"
"                 ":BufferExplorer"
"
"               (Personally, I map these to ,f and ,r and ,b)
"
"               The interface is intuitive.  When one of the explorers is
"               launched, a new window appears at bottom presenting a list of
"               files/dirs or buffers, and in the status bar is a prompt:
"
"                 >>
"
"               As you type, the list updates for possible matches using a
"               fuzzy matching algorithm.  Special keys include:
"
"                 <Enter>  open the selected match
"                 <Tab>    open the selected match
"                 <Esc>    cancel
"                 <C-c>    cancel
"                 <C-g>    cancel
"
"                 <C-t>    open the selected match in a new tab
"                 <C-n>    select the next match
"                 <C-p>    select the previous match
"                 <C-w>    ascend one directory at prompt
"                 <C-u>    clear the prompt
"
"               Additional shortcuts for the filesystem explorer:
"
"                 <C-r>    refresh directory contents
"                 <C-a>    open all files in the current list
"                 <C-e>    create a new file with the given name
"
" Buffer Explorer:
"  - The currently active buffer is highlighted.
"  - Buffers are listed without path unless needed to differentiate buffers of
"    the same name.
"
" Filesystem Explorer:
"  - Directory contents are memoized.
"  - You can recurse into and out of directories by typing the directory name
"    and a slash, e.g. "stuff/" or "../".
"  - Variable expansion, e.g. "$D" -> "/long/dir/path/".
"  - Tilde (~) expansion, e.g. "~/" -> "/home/steve/".
"  - Dotfiles are hidden by default, but are shown if the current search term
"    begins with a '.'.  To show these file at all times, set this option:
"
"       let g:LustyExplorerAlwaysShowDotFiles = 1
"
"  You can prevent certain files from appearing in the directory listings with
"  the following variable:
"
"    set wildignore=*.o,*.fasl,CVS
"
"  The above example will mask all object files, compiled lisp files, and
"  files/directories named CVS from appearing in the filesystem explorer.
"  Note that they can still be opened by being named explicitly.
"
"  See :help 'wildignore' for more information.
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
" turn off the "Sorry, LustyExplorer requires ruby" warning.  You can do so
" like this (in .vimrc):
"
"   let g:LustyExplorerSuppressRubyWarning = 1
"
" GetLatestVimScripts: 1890 1 :AutoInstall: lusty-explorer.vim
"
" TODO:
" - when an edited file is in nowrap mode and the explorer is called while the
"   current window is scrolled to the right, name truncation occurs.
" - bug: NO ENTRIES is not red when input is a space
"   - happens because LustyExpMatch declares after LustyExpNoEntries.
" - if new_hash == previous_hash, don't bother 'repainting'.

" Exit quickly when already loaded.
if exists("g:loaded_lustyexplorer")
  finish
endif

if exists("g:FuzzyFinderMode.TextMate")
  echohl WarningMsg
  echo "Warning: LustyExplorer detects the presence of fuzzyfinder_textmate;"
  echo "that plugin sometimes interacts poorly with other Ruby plugins."
  echohl none
endif

" Check for Ruby functionality.
if !has("ruby") || version < 700
  if !exists("g:LustyExplorerSuppressRubyWarning") ||
     \ g:LustyExplorerSuppressRubyWarning == "0"
  if !exists("g:LustyJugglerSuppressRubyWarning") ||
      \ g:LustyJugglerSuppressRubyWarning == "0"
    echohl ErrorMsg
    echon "Sorry, LustyExplorer requires ruby.  "
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
    echo "         # make && make install"

    echo "(If you just wish to stifle this message, set the following option:"
    echo "  let g:LustyJugglerSuppressRubyWarning = 1)"
    echohl none
  endif
  endif
  finish
endif

let g:loaded_lustyexplorer = "yep"

" Commands.
command BufferExplorer :call <SID>BufferExplorerStart()
command FilesystemExplorer :call <SID>FilesystemExplorerStart()
command FilesystemExplorerFromHere :call <SID>FilesystemExplorerStartFromHere()

" Default mappings.
nmap <silent> <Leader>lf :FilesystemExplorer<CR>
nmap <silent> <Leader>lr :FilesystemExplorerFromHere<CR>
nmap <silent> <Leader>lb :BufferExplorer<CR>

" Old mappings (from DynamicExplorer).
nmap <silent> <Leader>df :FilesystemExplorer<CR>
nmap <silent> <Leader>db :BufferExplorer<CR>

" Vim-to-ruby function calls.
function! s:FilesystemExplorerStart()
  ruby $filesystem_explorer.run_from_wd
endfunction

function! s:FilesystemExplorerStartFromHere()
  ruby $filesystem_explorer.run_from_here
endfunction

function! s:BufferExplorerStart()
  ruby $buffer_explorer.run
endfunction

function! FilesystemExplorerCancel()
  ruby $filesystem_explorer.cancel
endfunction

function! BufferExplorerCancel()
  ruby $buffer_explorer.cancel
endfunction

function! FilesystemExplorerKeyPressed(code_arg)
  ruby $filesystem_explorer.key_pressed
endfunction

function! BufferExplorerKeyPressed(code_arg)
  ruby $buffer_explorer.key_pressed
endfunction

" Setup the autocommands that handle buffer MRU ordering.
"augroup LustyExplorer
"  autocmd!
"  autocmd BufEnter * ruby Window.buffer_stack.push
"  autocmd BufDelete * ruby Window.buffer_stack.pop
"  autocmd BufWipeout * ruby Window.buffer_stack.pop
"augroup End

ruby << EOF
require 'pathname'

# PROFILING
#require 'rubygems'
#require 'ruby-prof'

class String
  def ends_with?(s)
    tail = self[-s.length, s.length]
    tail == s
  end

  def starts_with?(s)
    head = self[0, s.length]
    head == s
  end
end

class IO
  def ready_for_read?
    result = IO.select([self], nil, nil, 0)
    result && (result.first.first == self)
  end
end

class File
  def self.simplify_path(s)
    begin
      if s[0] == '~'[0]
        s = File.expand_path(s.sub(/\/.*/,'')) + \
            s.sub(/^[^\/]+/,'')
      end

      if s.ends_with?(File::SEPARATOR)
        File.expand_path(s) + File::SEPARATOR
      else
        File.expand_path(File.dirname(s)) + File::SEPARATOR + File.basename(s)
      end
    rescue ArgumentError
      s
    end
  end
end

module VIM
  def self.has_syntax?
    eva('has("syntax")') != "0"
  end

  def self.columns
    eva("&columns").to_i
  end

  def self.lines
    eva("&lines").to_i
  end

  def self.getcwd
    eva("getcwd()")
  end

  def self.single_quote_escape(s)
    # Everything in a Vim single quoted string is literal, except single quotes.
    # Single quotes are escaped by doubling them.
    s.gsub("'", "''")
  end

  def self.filename_escape(s)
    # Escape slashes, open square braces, spaces, sharps, and double quotes.
    s.gsub(/\\/, '\\\\\\').gsub(/[\[ #"]/, '\\\\\0')
  end

  def self.regex_escape(s)
    s.gsub(/[\]\[.~"^$\\*]/,'\\\\\0')
  end

  class Buffer
    def modified?
      eva("getbufvar(#{number()}, '&modified')") != "0"
    end
  end
end

def lusty_option_set?(opt_name)
  opt_name = "g:LustyExplorer" + opt_name
  eva("exists('#{opt_name}') && #{opt_name} != '0'") != "0"
end

# Port of Ryan McGeary's LiquidMetal fuzzy matching algorithm found at:
#   http://github.com/rmm5t/liquidmetal/tree/master.
class LiquidMetal
  @@SCORE_NO_MATCH = 0.0
  @@SCORE_MATCH = 1.0
  @@SCORE_TRAILING = 0.8
  @@SCORE_TRAILING_BUT_STARTED = 0.90
  @@SCORE_BUFFER = 0.85

  def self.score(string, abbrev)

    return @@SCORE_TRAILING if abbrev.empty?
    return @@SCORE_NO_MATCH if abbrev.length > string.length

    scores = buildScoreArray(string, abbrev)

    sum = scores.inject { |a, b| a + b }

    return sum / scores.length;
  end

  def self.buildScoreArray(string, abbrev)
    scores = Array.new(string.length)
    lower = string.downcase()

    lastIndex = -1
    started = false

    abbrev.downcase().each_byte do |c|
      index = lower.index(c, lastIndex + 1)
      return scores.fill(@@SCORE_NO_MATCH, 0..-1) if index.nil?
      started = true if index == 0

      if index > 0 and " \t/._-".include?(string[index - 1])
        scores[index - 1] = @@SCORE_MATCH
        scores.fill(@@SCORE_BUFFER, (lastIndex + 1)...(index - 1))
      elsif string[index] >= "A"[0] and string[index] <= "Z"[0]
        scores.fill(@@SCORE_BUFFER, (lastIndex + 1)...index)
      else
        scores.fill(@@SCORE_NO_MATCH, (lastIndex + 1)...index)
      end

      scores[index] = @@SCORE_MATCH
      lastIndex = index
    end

    trailing_score = started ? @@SCORE_TRAILING_BUT_STARTED : @@SCORE_TRAILING
    scores.fill(trailing_score, lastIndex + 1)
    return scores
  end
end

# Used in FilesystemExplorer
class Entry
  attr_accessor :name, :current_score
  def initialize(name)
    @name = name
    @current_score = 0.0
  end
end

# Used in BufferExplorer
class BufferEntry < Entry
  attr_accessor :full_name, :vim_buffer
  def initialize(vim_buffer)
    @full_name = vim_buffer.name
    @vim_buffer = vim_buffer
    @name = "::UNSET::"
    @current_score = 0.0
  end
end

class LustyExplorer
  public
    def initialize
      @settings = SavedSettings.new
      @displayer = Displayer.new title()
      @prompt = nil
      @ordered_matching_entries = []
      @running = false
    end

    def run
      return if @running

      @settings.save
      @running = true
      @calling_window = $curwin
      @saved_alternate_bufnum = if eva("expand('#')").empty?
                                  nil
                                else
                                  eva("bufnr(expand('#'))")
                                end
      @selected_index = 0
      create_explorer_window()
      refresh(:full)
    end

    def key_pressed()
      # Grab argument from the Vim function.
      i = eva("a:code_arg").to_i
      refresh_mode = :full

      case i
        when 32..126          # Printable characters
          c = i.chr
          @prompt.add! c
          @selected_index = 0
        when 8                # Backspace/Del/C-h
          @prompt.backspace!
          @selected_index = 0
        when 9, 13            # Tab and Enter
          choose(:current_tab)
          @selected_index = 0
        when 23               # C-w (delete 1 dir backward)
          @prompt.up_one_dir!
          @selected_index = 0
        when 14               # C-n (select next)
          @selected_index = \
            (@selected_index + 1) % @ordered_matching_entries.size
          refresh_mode = :no_recompute
        when 16               # C-p (select previous)
          @selected_index = \
            (@selected_index - 1) % @ordered_matching_entries.size
          refresh_mode = :no_recompute
        when 20               # C-t choose in new tab
          choose(:new_tab)
          @selected_index = 0
        when 21               # C-u clear prompt
          @prompt.clear!
          @selected_index = 0
      end

      refresh(refresh_mode)
    end

    def cancel
      if @running
        cleanup()
        # fix alternate file
        if @saved_alternate_bufnum
          cur = $curbuf
          exe "silent b #{@saved_alternate_bufnum}"
          exe "silent b #{cur.number}"
        end

        # PROFILING
        #outfile = File.new('rbprof.txt', 'a')
        #RubyProf::CallTreePrinter.new(RubyProf.stop).print(outfile)
      end
    end

  private
    def refresh(mode)
      return if not @running

      if mode == :full
        @ordered_matching_entries = compute_ordered_matching_entries()
      end

      on_refresh()
      highlight_selected_index()
      @displayer.print @ordered_matching_entries.map { |x| x.name }
      @prompt.print
    end

    def create_explorer_window

      @displayer.create

      # Setup key mappings to reroute user input.

      # Non-special printable characters.
      printables =  '/!"#$%&\'()*+,-.0123456789:<=>?#@"' \
                    'ABCDEFGHIJKLMNOPQRSTUVWXYZ' \
                    '[]^_`abcdefghijklmnopqrstuvwxyz{}~'

      map_command = "noremap <silent> <buffer> "

      printables.each_byte do |b|
        exe "#{map_command} <Char-#{b}> :call #{self.class}KeyPressed(#{b})<CR>"
      end

      # Special characters
      exe "#{map_command} <Tab>    :call #{self.class}KeyPressed(9)<CR>"
      exe "#{map_command} <Bslash> :call #{self.class}KeyPressed(92)<CR>"
      exe "#{map_command} <Space>  :call #{self.class}KeyPressed(32)<CR>"
      exe "#{map_command} \026|    :call #{self.class}KeyPressed(124)<CR>"

      exe "#{map_command} <BS>     :call #{self.class}KeyPressed(8)<CR>"
      exe "#{map_command} <Del>    :call #{self.class}KeyPressed(8)<CR>"
      exe "#{map_command} <C-h>    :call #{self.class}KeyPressed(8)<CR>"

      exe "#{map_command} <CR>     :call #{self.class}KeyPressed(13)<CR>"
      exe "#{map_command} <S-CR>   :call #{self.class}KeyPressed(10)<CR>"
      exe "#{map_command} <C-a>    :call #{self.class}KeyPressed(1)<CR>"

      exe "#{map_command} <Esc>    :call #{self.class}Cancel()<CR>"
      exe "#{map_command} <C-c>    :call #{self.class}Cancel()<CR>"
      exe "#{map_command} <C-g>    :call #{self.class}Cancel()<CR>"

      exe "#{map_command} <C-w>    :call #{self.class}KeyPressed(23)<CR>"
      exe "#{map_command} <C-n>    :call #{self.class}KeyPressed(14)<CR>"
      exe "#{map_command} <C-p>    :call #{self.class}KeyPressed(16)<CR>"
      exe "#{map_command} <C-t>    :call #{self.class}KeyPressed(20)<CR>"
      exe "#{map_command} <C-e>    :call #{self.class}KeyPressed(5)<CR>"
      exe "#{map_command} <C-r>    :call #{self.class}KeyPressed(18)<CR>"
      exe "#{map_command} <C-u>    :call #{self.class}KeyPressed(21)<CR>"
    end

    def highlight_selected_index
      return unless VIM::has_syntax?

      entry = @ordered_matching_entries[@selected_index]
      return if entry.nil?

      exe "syn clear LustyExpSelected"
      exe "syn match LustyExpSelected " \
	  "\"#{Displayer.vim_match_string(entry.name, false)}\" "
    end

    def compute_ordered_matching_entries
      abbrev = current_abbreviation()
      unordered = matching_entries()

      # Sort alphabetically if there's just a dot or we have no abbreviation,
      # otherwise it just looks weird.
      if abbrev.length == 0 or abbrev == '.'
        unordered.sort! { |x, y| x.name <=> y.name }
      else
        # Sort by score.
        unordered.sort! { |x, y| y.current_score <=> x.current_score }
      end
    end

    def matching_entries
      all_entries().select { |x|
        x.current_score = LiquidMetal.score(x.name, current_abbreviation())
        x.current_score != 0.0
      }
    end

    def choose(open_mode)
      entry = @ordered_matching_entries[@selected_index]
      return if entry.nil?
      @selected_index = 0
      open_entry(entry, open_mode)
    end

    def cleanup
      @displayer.close
      Window.select @calling_window
      @settings.restore
      @running = false
      msg ""
      assert(@calling_window == $curwin)
    end
end


class BufferExplorer < LustyExplorer
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
        fill_buffer_entries()
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
        exe 'syn clear LustyExpCurrentBuffer'
        exe "syn match LustyExpCurrentBuffer \"#{curbuf_match_string()}\" " \
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

    def fill_buffer_entries
      @buffer_entries.clear
      (0..VIM::Buffer.count-1).each do |i|
        @buffer_entries << BufferEntry.new(VIM::Buffer[i])
      end

      # Shorten each buffer name by removing all path elements which are not
      # needed to differentiate a given name from other names.  This usually
      # results in only the basename shown, but if several buffers of the
      # same basename are opened, there will be more.

      # Group the buffers by common basename
      common_base = Hash.new { |hash, k| hash[k] = [] }
      @buffer_entries.each do |entry|
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
      @buffer_entries.each do |entry|
        full_name = entry.full_name

        short_name = if full_name.nil?
                       '[No Name]'
                     elsif full_name.starts_with?("scp://")
                       full_name
                     else
                       base = Pathname.new(full_name).basename.to_s
                       prefix = basename_to_prefix[base]

                       prefix ? full_name[prefix.length..-1] \
                              : base
                     end

        # Disabled: show buffer number next to name
        #short_name += ' ' + buffer.number.to_s

        # Show modification indicator
        short_name += entry.vim_buffer.modified? ? " [+]" : ""

        entry.name = short_name
      end
    end

    def current_abbreviation
      @prompt.input
    end

    def all_entries
      @buffer_entries
    end

    def open_entry(entry, open_mode)
      cleanup()
      assert($curwin == @calling_window)

      number = entry.vim_buffer.number
      assert(number)

      cmd = case open_mode
            when :current_tab
              "b"
            when :new_tab
              # For some reason just using tabe or e gives an error when
              # the alternate-file isn't set.
              "tab split | b"
            else
              assert(false, "bad open mode")
            end

      exe "silent #{cmd} #{number}"
    end
end

def time
  # PROFILING
  #RubyProf.resume
  begin
    yield
  rescue Exception => e
    puts e
    puts e.backtrace
  end
  #RubyProf.pause
end

class FilesystemExplorer < LustyExplorer
  public
    def initialize
      super
      @prompt = FilesystemPrompt.new
      @memoized_entries = {}
    end

    def run
      FileMasks.create_glob_masks()
      @vim_swaps = VimSwaps.new
      super
    end

    def run_from_here
      start_path = if $curbuf.name.nil?
                     VIM::getcwd()
                   else
                     eva("expand('%:p:h')")
                   end

      @prompt.set!(start_path + File::SEPARATOR)
      run()
    end

    def run_from_wd
      @prompt.set!(VIM::getcwd() + File::SEPARATOR)
      run()
    end

    def key_pressed()
      time do
      i = eva("a:code_arg").to_i

      case i
      when 1, 10  # <C-a>, <Shift-Enter>
        cleanup()
        # Open all non-directories currently in view.
        @ordered_matching_entries.each do |e|
          path_str = \
            if @prompt.at_dir?
              @prompt.input + e.name
            else
              @prompt.dirname + File::SEPARATOR + e.name
            end

          load_file(path_str, :current_tab) unless File.directory?(path_str)
        end
      when 5      # <C-e> edit file, create it if necessary
        if not @prompt.at_dir?
          cleanup()
          # Force a reread of this directory so that the new file will
          # show up (as long as it is saved before the next run).
          @memoized_entries.delete(view_path())
          load_file(@prompt.input, :current_tab)
        end
      when 18     # <C-r> refresh
        @memoized_entries.delete(view_path())
        refresh(:full)
      else
        super
      end
      end
    end

  private
    def title
    '[LustyExplorer-Files]'
    end

    def on_refresh
      if VIM::has_syntax?
        exe 'syn clear LustyExpFileWithSwap'

        view = view_path()
        @vim_swaps.file_names.each do |file_with_swap|
          if file_with_swap.dirname == view
            base = file_with_swap.basename
            match_str = Displayer.vim_match_string(base.to_s, false)
            exe "syn match LustyExpFileWithSwap \"#{match_str}\""
          end
        end
      end

      # TODO: restore highlighting for open buffers?
    end

    def current_abbreviation
      if @prompt.at_dir?
        ""
      else
        File.basename(@prompt.input)
      end
    end

    def view_path
      input = @prompt.input

      path = \
        if @prompt.at_dir? and \
           input.length > 1         # Not root
          # The last element in the path is a directory + '/' and we want to
          # see what's in it instead of what's in its parent directory.

          Pathname.new(input[0..-2])  # Canonicalize by removing trailing '/'
        else
          Pathname.new(input).dirname
        end

      return path
    end

    def all_entries
      view = view_path()

      if not view.exist?
        return []
      elsif not view.readable?
        # TODO: show "-- PERMISSION DENIED --"
        return []
      end

      unless @memoized_entries.has_key?(view)
        # Generate an array of the files
        entries = []
        view.each_entry do |file|
          name = file.basename.to_s
          next if name == "."   # Skip pwd
          next if name == ".." and lusty_option_set?("AlwaysShowDotFiles")

          # Hide masked files.
          next if FileMasks.masked?(name)

          if (view + file).directory?
            # ^^ bug in Pathname.each_entry -- block variable has no dir.
            name += File::SEPARATOR
          end
          entries << Entry.new(name)
        end
        @memoized_entries[view] = entries
      end

      all = @memoized_entries[view]

      if lusty_option_set?("AlwaysShowDotFiles") or \
         current_abbreviation()[0] == '.'[0]
        all
      else
        # Filter out dotfiles if the current abbreviation doesn't start with
        # '.'.
        all.select { |x| x.name[0] != '.'[0] }
      end
    end

    def open_entry(entry, open_mode)
      path = view_path() + entry.name

      if File.directory?(path)
        # Recurse into the directory instead of opening it.
        @prompt.set!(path.to_s)
      elsif entry.name.include?(File::SEPARATOR)
        # Don't open a fake file/buffer with "/" in its name.
        return
      else
        cleanup()
        load_file(path.to_s, open_mode)
      end
    end

    def load_file(path_str, open_mode)
      assert($curwin == @calling_window)
      # Escape for Vim and remove leading ./ for files in pwd.
      escaped = VIM::filename_escape(path_str).sub(/^\.\//,"")
      sanitized = eva "fnamemodify('#{escaped}', ':p')"
      cmd = case open_mode
            when :current_tab
              "e"
            when :new_tab
              "tabe"
            else
              assert(false, "bad open mode")
            end

      exe "silent #{cmd} #{sanitized}"
    end
end


class Prompt
  private
    @@PROMPT = ">> "

  public
    def initialize
      clear!
    end

    def clear!
      @input = ""
    end

    def print
      pretty_msg("Comment", @@PROMPT, "None", @input, "Underlined", " ")
    end

    def set!(s)
      @input = s
    end

    def input
      @input
    end

    def insensitive?
      @input == @input.downcase
    end

    def ends_with?(c)
      @input.ends_with? c
    end

    def add!(s)
      @input += s
    end

    def backspace!
      @input.chop!
    end

    def up_one_dir!
      @input.chop!
      while !@input.empty? and @input[-1] != '/'[0]
        @input.chop!
      end
    end
end

class FilesystemPrompt < Prompt

  def initialize
    super
    @memoized = nil
    @dirty = true
  end

  def clear!
    @dirty = true
    super
  end

  def set!(s)
    @dirty = true
    # On Windows, Vim will return paths with a '\' separator, but
    # we want to use '/'.
    super(s.gsub('\\', '/'))
  end

  def backspace!
    @dirty = true
    super
  end

  def up_one_dir!
    @dirty = true
    super
  end

  def at_dir?
    # We have not typed anything yet or have just typed the final '/' on a
    # directory name in pwd.  This check is interspersed throughout
    # FilesystemExplorer because of the conventions of basename and dirname.
    input().empty? or \
    (File.directory?(input()) and input().ends_with?(File::SEPARATOR))
  end

  def insensitive?
    at_dir? or (basename() == basename().downcase)
  end

  def add!(s)
    # Assumption: add!() will only receive enough chars at a time to complete
    # a single directory level, e.g. foo/, not foo/bar/

    @input += s
    @dirty = true
  end

  def input
    if @dirty
      @memoized = variable_expansion(File.simplify_path(@input))
      @dirty = false
    end

    @memoized
  end

  def basename
    File.basename input()
  end

  def dirname
    File.dirname input()
  end

  private
    def variable_expansion (input_str)
      # FIXME does this still work?
      strings = input_str.split('$', -1)
      return "" if strings.nil? or strings.length == 0

      first = strings.shift

      # Try to expand each instance of $<word>.
      strings.inject(first) { |str, s|
        if s =~ /^(\w+)/ and ENV[$1]
          str + s.sub($1, ENV[$1])
        else
          str + "$" + s
        end
      }
    end
end

# Simplify switching between windows.
class Window
    def Window.select(window)
      return true if window == $curwin

      start = $curwin

      # Try to select the given window.
      begin
        exe "wincmd w"
      end while ($curwin != window) and ($curwin != start)

      if $curwin == window
        return true
      else
        # Failed -- re-select the starting window.
        exe("wincmd w") while $curwin != start
        pretty_msg("ErrorMsg", "Cannot find the correct window!")
        return false
      end
    end
end

# Save and restore settings when creating the explorer buffer.
class SavedSettings
  def initialize
    save()
  end

  def save
    @timeoutlen = eva "&timeoutlen"

    @splitbelow = eva("&splitbelow") == "1"
    @insertmode = eva("&insertmode") == "1"
    @showcmd = eva("&showcmd") == "1"
    @list = eva("&list") == "1"

    @report = eva "&report"
    @sidescroll = eva "&sidescroll"
    @sidescrolloff = eva "&sidescrolloff"
  end

  def restore
    set "timeoutlen=#{@timeoutlen}"

    if @splitbelow
      set "splitbelow"
    else
      set "nosplitbelow"
    end

    if @insertmode
      set "insertmode"
    else
      set "noinsertmode"
    end

    if @showcmd
      set "showcmd"
    else
      set "noshowcmd"
    end

    if @list
      set "list"
    else
      set "nolist"
    end

    exe "set report=#{@report}"
    exe "set sidescroll=#{@sidescroll}"
    exe "set sidescrolloff=#{@sidescrolloff}"
  end
end

# Manage the explorer buffer.
class Displayer
  private
    @@COLUMN_SEPARATOR = "    "
    @@NO_ENTRIES_STRING = "-- NO ENTRIES --"
    @@TRUNCATED_STRING = "-- TRUNCATED --"

  public
    def Displayer.vim_match_string(s, case_insensitive)
      # Create a match regex string for the given s.  This is for a Vim regex,
      # not for a Ruby regex.

      str = '\%(^\|' + @@COLUMN_SEPARATOR + '\)' \
            '\zs' + VIM::regex_escape(s) + '\%( \[+\]\)\?' + '\ze' \
            '\%(\s*$\|' + @@COLUMN_SEPARATOR + '\)'

      str += '\c' if case_insensitive

      return str
    end

    def initialize(title)
      @title = title
      @window = nil
      @buffer = nil
    end

    def create
      # Make a window for the displayer and move there.
      exe "silent! botright split #{@title}"

      @window = $curwin
      @buffer = $curbuf

      # Displayer buffer is special.
      exe "setlocal bufhidden=delete"
      exe "setlocal buftype=nofile"
      exe "setlocal nomodifiable"
      exe "setlocal noswapfile"
      exe "setlocal nowrap"
      exe "setlocal nonumber"
      exe "setlocal foldcolumn=0"
      exe "setlocal nocursorline"
      exe "setlocal nospell"
      exe "setlocal nobuflisted"
      exe "setlocal textwidth=0"

      # (Update SavedSettings if adding to below.)
      set "timeoutlen=0"
      set "noinsertmode"
      set "noshowcmd"
      set "nolist"
      set "report=9999"
      set "sidescroll=0"
      set "sidescrolloff=0"

      # TODO -- cpoptions?

      if VIM::has_syntax?
        exe 'syn match LustyExpSlash "/" contained'
        exe 'syn match LustyExpDir "\zs\%(\S\+ \)*\S\+/\ze" ' \
                                   'contains=LustyExpSlash'

        exe 'syn match LustyExpModified " \[+\]"'

        exe 'syn match LustyExpNoEntries "\%^\s*' \
                                         "#{@@NO_ENTRIES_STRING}" \
                                         '\s*\%$"'

        exe 'syn match LustyExpTruncated "^\s*' \
                                         "#{@@TRUNCATED_STRING}" \
                                         '\s*$"'

        exe 'highlight link LustyExpDir Directory'
        exe 'highlight link LustyExpSlash Function'
        exe 'highlight link LustyExpSelected Type'
        exe 'highlight link LustyExpModified Special'
        exe 'highlight link LustyExpCurrentBuffer Constant'
        exe 'highlight link LustyExpOpenedFile PreProc'
        exe 'highlight link LustyExpFileWithSwap WarningMsg'
        exe 'highlight link LustyExpNoEntries ErrorMsg'
        exe 'highlight link LustyExpTruncated Visual'
      end
    end

    def print(strings)
      Window.select(@window) || return

      if strings.empty?
        print_no_entries()
        return
      end

      # Perhaps truncate the results to just over the upper bound of
      # displayable strings.  This isn't exact, but it's close enough.
      max = VIM::lines * (VIM::columns / (1 + @@COLUMN_SEPARATOR.length))
      if strings.length > max
        strings.slice!(max, strings.length - max)
      end

      # Get a high upper bound on the number of columns to display to optimize
      # the following algorithm a little.
      col_count = column_count_upper_bound(strings)

      # Figure out the actual number of columns to use (yuck)
      cols = nil
      widths = nil
      while col_count > 1 do

        cols = columnize(strings, col_count);

        widths = cols.map { |col|
          col.max { |a, b| a.length <=> b.length }.length
        }

        full_width = widths.inject { |sum, n| sum + n }
        full_width += @@COLUMN_SEPARATOR.length * (col_count - 1)

        if full_width <= $curwin.width
          break
        end

        col_count -= 1
      end

      if col_count <= 1
        cols = [strings]
        widths = [0]
      end

      print_columns(cols, widths)
    end

    def close
      # Only wipe the buffer if we're *sure* it's the explorer.
      if Window.select @window and \
         $curbuf == @buffer and \
         $curbuf.name =~ /#{Regexp.escape(@title)}$/
          exe "bwipeout!"
          @window = nil
          @buffer = nil
      end
    end

  private
    def print_columns(cols, widths)
      unlock_and_clear()

      # Set the height to the height of the longest column.
      $curwin.height = cols.max { |a, b| a.length <=> b.length }.length

      (0..$curwin.height-1).each do |i|

        string = ""
        (0..cols.length-1).each do |j|
          break if cols[j][i].nil?
          string += cols[j][i]
          string += " " * [(widths[j] - cols[j][i].length), 0].max
          string += @@COLUMN_SEPARATOR
        end

        # Stretch the line to the length of the window with whitespace so that
        # we can "hide" the cursor in the corner.
        string += " " * [($curwin.width - string.length), 0].max

        $curwin.cursor = [i+1, 1]
        $curbuf.append(i, string)
      end

      # Check for result truncation.
      if cols[0][$curwin.height]
        # Show a truncation indicator.
        $curbuf.delete($curbuf.count - 1)
        $curwin.cursor = [$curbuf.count, 1]
        $curbuf.append($curbuf.count - 1, \
                       @@TRUNCATED_STRING.center($curwin.width, " "))
      end

      # There's a blank line at the end of the buffer because of how
      # VIM::Buffer.append works.
      $curbuf.delete $curbuf.count
      lock()
    end

    def print_no_entries
      unlock_and_clear()
      $curwin.height = 1

      $curbuf[1] = @@NO_ENTRIES_STRING.center($curwin.width, " ")
      lock()
    end

    def unlock_and_clear
      exe "setlocal modifiable"

      # Clear the explorer (black hole register)
      exe "silent %d _"
    end

    def lock
      exe "setlocal nomodifiable"

      # Hide the cursor
      exe "normal! Gg$"
    end

    # Get a starting upper bound on the number of columns
    def column_count_upper_bound(strings)
      column_count = 0
      length = 0

      sorted_by_length = strings.sort {|x, y| x.length <=> y.length }

      sorted_by_length.each do |e|
        length += e.length
        break unless length < $curwin.width

        column_count += 1
        length += @@COLUMN_SEPARATOR.length
      end

      return column_count
    end

    def columnize(strings, n_cols)
      n_rows = (strings.length.to_f / n_cols).ceil

      # Break the array into sub arrays representing columns
      cols = []
      0.step(strings.size-1, n_rows) do |i|
        cols << strings[i..(i + n_rows - 1)]
      end
      return cols
    end
end


class FileMasks
  private
    @@glob_masks = []

  public
    def FileMasks.create_glob_masks
      @@glob_masks = if eva('exists("g:LustyExplorerFileMasks")') != "0"
                       # Note: this variable deprecated.
                       eva("g:LustyExplorerFileMasks").split(',')
                     elsif eva('exists("&wildignore")') != "0"
                       eva("&wildignore").split(',')
                     else
                       []
                     end
    end

    def FileMasks.masked?(str)
      @@glob_masks.each do |mask|
        return true if File.fnmatch(mask, str)
      end

      return false
    end
end

class VimSwaps
  def initialize
    if VIM::has_syntax?
# FIXME: vvv disabled
#      @vim_r = IO.popen("vim -r 2>&1")
#      @files_with_swaps = nil
      @files_with_swaps = []
    else
      @files_with_swaps = []
    end
  end

  def file_names
    if @files_with_swaps.nil?
      if @vim_r.ready_for_read?
        @files_with_swaps = []
        @vim_r.each_line do |line|
          if line =~ /^ +file name: (.*)$/
            file = $1.chomp
            @files_with_swaps << Pathname.new(File.simplify_path(file))
          end
        end
      else
        return []
      end
    end

    @files_with_swaps
  end
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

def pretty_msg(*rest)
  return if rest.length == 0
  return if rest.length % 2 != 0

  exe "redraw"  # see :help echo-redraw
  i = 0
  while i < rest.length do
    exe "echohl #{rest[i]}"
    exe "echon '#{rest[i+1]}'"
    i += 2
  end

  exe 'echohl None'
end

class AssertionError < StandardError
end

def assert(condition, message = 'assertion failure')
  raise AssertionError.new(message) unless condition
end


$buffer_explorer = BufferExplorer.new
$filesystem_explorer = FilesystemExplorer.new

EOF

" vim: set sts=2 sw=2:
