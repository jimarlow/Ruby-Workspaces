require 'fox16'
include Fox
require 'stringio'

# NOTE: Check out RiReader to add documentation

class ListDialog < FXDialogBox

  def initialize( owner, title, width = 200, height = 300 )
    super( owner, title, DECOR_TITLE|DECOR_BORDER|DECOR_RESIZE|DECOR_CLOSE, 0, 0, width, height )
    # Add components
    list_frame = FXVerticalFrame.new( self, :opts => LAYOUT_FILL|LAYOUT_SIDE_BOTTOM )
    @list = FXList.new( list_frame, :target => self, :selector => FXDialogBox::ID_ACCEPT, opts: LAYOUT_FILL|LIST_SINGLESELECT )
  end

  def items=( items )
    @list.clearItems
    items.each { |i| @list.appendItem( i.to_s ) }
  end

  def selected_item
    return @list.getItem( @list.currentItem )
  end

end

class RubyWorkspaceMainWindow < FXMainWindow

  def initialize(anApp)
    super(anApp, "Ruby Workspace", nil, nil, DECOR_ALL, 0, 0, 400, 300)

    @file_name = nil

    @binding = binding()

    # Menubar - this goes first to grab space at the top of the frame
    @menubar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)

    # Status bar - this goes next to grab space at the bottom of the frame
    @statusbar = FXStatusBar.new(self, LAYOUT_SIDE_BOTTOM|LAYOUT_FILL_X|STATUSBAR_WITH_DRAGCORNER)

    @editor = FXText.new(self, nil, 0, LAYOUT_FILL_X|LAYOUT_FILL_Y|TEXT_WORDWRAP)
    @editor.connect( SEL_RIGHTBUTTONRELEASE ) {|sender, sel, event| @do_it_menu.popup(nil, event.root_x, event.root_y)}

    # Make the menus last because they refer to objects created above
    self.make_menus
  end

  def make_menus
    # File menu
    file_menu = FXMenuPane.new(self)
    FXMenuCommand.new(file_menu, "Open\tCtl-O" ).connect( SEL_COMMAND, method( :menu_open ) )
    FXMenuSeparator.new( file_menu )
    FXMenuCommand.new(file_menu, "New\tCtl-N" ).connect( SEL_COMMAND, method( :menu_new ) )
    FXMenuSeparator.new( file_menu )
    @save_menu = FXMenuCommand.new(file_menu, "Save\tCtl-S" )
    @save_menu.connect( SEL_COMMAND, method( :menu_save ) )
    @save_menu.disable
    FXMenuCommand.new(file_menu, "Save As...\tCtl-Shift-S").connect( SEL_COMMAND, method( :menu_save_as ) )
    FXMenuCommand.new(file_menu, "Save Selection As...").connect( SEL_COMMAND, method( :menu_save_selection_as ) )
    FXMenuSeparator.new( file_menu )
    FXMenuCommand.new(file_menu, "Quit\tCtl-Q", nil, getApp(), FXApp::ID_QUIT)
    FXMenuTitle.new( @menubar, "&File", nil, file_menu )

    # Edit menu
    edit_menu = FXMenuPane.new(self)
    FXMenuCommand.new(edit_menu, "&Copy\tCtl-C\tCopy selection to clipboard.", nil, @editor, FXText::ID_COPY_SEL )
    FXMenuCommand.new(edit_menu, "Cu&t\tCtl-X\tCut selection to clipboard.", nil, @editor, FXText::ID_CUT_SEL )
    FXMenuCommand.new(edit_menu, "&Paste\tCtl-V\tPaste from clipboard.", nil, @editor, FXText::ID_PASTE_SEL )
    FXMenuCommand.new(edit_menu, "&Delete\t\tDelete selection.", nil, @editor, FXText::ID_DELETE_SEL )
    FXMenuTitle.new(@menubar, "&Edit", nil, edit_menu)

    # Do it, Show it popup menu
    @do_it_menu = FXMenuPane.new(self)
    FXMenuCommand.new(@do_it_menu, "Do it" ).connect( SEL_COMMAND, method( :do_it ) )
    FXMenuCommand.new(@do_it_menu, "Show it" ).connect( SEL_COMMAND, method( :show_it ) )
    FXMenuCommand.new(@do_it_menu, "Append it" ).connect( SEL_COMMAND, method( :append_it ) )
    FXMenuCommand.new(@do_it_menu, "Methods" ).connect( SEL_COMMAND, method( :menu_methods ) )
  end

  def create
    super
    show(PLACEMENT_SCREEN)
  end

  # Menu commands
  def menu_save( sender = nil, sel = nil, ptr  = nil)
    @file_name ? save_file( @editor.text ) : menu_save_as
  end

  def menu_save_as( sender = nil, sel = nil, ptr  = nil)
    dialog = FXFileDialog.new(self, "Save Workspace")
    dialog.patternList = [ "Ruby Workspace Files (*.rbw)", "All Files (*)"]
    if dialog.execute != 0
      @file_name = dialog.filename
      save_file( @editor.text )
    end
  end

  def save_file( text )
    File.open( @file_name, "w+" ) do |f|
        f.write( text )
        @statusbar.statusLine.normalText = @file_name
        @save_menu.enable
      end
  end

  def menu_save_selection_as( sender = nil, sel = nil, ptr  = nil)
    dialog = FXFileDialog.new(self, "Save Selection")
    dialog.patternList = [ "All Files (*)" ]
    if dialog.execute != 0
      @file_name = dialog.filename
      save_file( get_selected_text )
    end
  end

  def menu_open( sender, sel, ptr )
    dialog = FXFileDialog.new(self, "Open Workspace")
    dialog.patternList = [ "Ruby Workspace Files (*.rbw)", "All Files (*)" ]
    dialog.selectMode = SELECTFILE_EXISTING
    if dialog.execute != 0
      @file_name = dialog.filename
      @editor.text = File.open( @file_name ).readlines.join
      @statusbar.statusLine.normalText = @file_name
      @save_menu.enable
    end
  end

  def menu_new( sender, sel, ptr )
    dialog = FXFileDialog.new(self, "Open Workspace")
    dialog.patternList = [ "Ruby Workspace Files (*.rbw)", "All Files (*)" ]
    if dialog.execute != 0
      @file_name = dialog.filename
      @statusbar.statusLine.normalText = @file_name
      @editor.text = ""
    end
  end

  def get_selected_text
    if @editor.selEndPos > @editor.selStartPos then
      return @editor.text[ @editor.selStartPos, @editor.selEndPos - @editor.selStartPos]
    else
      # If nothing is selected, return the whole line
      line_start = @editor.lineStart(@editor.cursorPos)
      line_end = @editor.lineEnd(@editor.cursorPos)
      #puts @editor.text[ line_start, @editor.cursorPos - line_start ]
      return @editor.text[ line_start, line_end - line_start ]
    end
  end

  def menu_methods( sender, sel, ptr )
    text = get_selected_text
    begin
      object_methods = eval( text, @binding ).class.instance_methods( false )
      dialog = ListDialog.new( self, "Instance Methods" )
      dialog.items = object_methods
      @editor.insertText( @editor.lineEnd(@editor.cursorPos), ".#{dialog.selected_item.to_s}"  ) if dialog.execute != 0
    rescue SyntaxError, NameError => e1
      FXMessageBox.warning( self, MBOX_OK, "Error", "String doesn't compile: " + e1.to_s )
    rescue StandardError => e2
      FXMessageBox.warning( self, MBOX_OK, "Error", "Error running script: " + e2.to_s )
    end
  end

  def do_it( sender, sel, ptr )
    begin
      ret = eval( get_selected_text, @binding )
      return ret
    rescue SyntaxError, NameError => e1
      FXMessageBox.warning( self, MBOX_OK, "Error", "String doesn't compile: " + e1.to_s )
      return nil
    rescue StandardError => e2
      FXMessageBox.warning( self, MBOX_OK, "Error", "Error running script: " + e2.to_s )
      return nil
    end
  end

  def show_it( sender, sel, ptr )
    $stdout = out = StringIO.new  # Get standard output 
    ret = do_it( sender, sel, ptr )
    $stdout = STDOUT              # It's important to restore $stdout otherwise you get an error
    @editor.insertText( @editor.lineEnd(@editor.cursorPos), "\n" + ret.inspect + "\n" + out.string )
  end

  def append_it( sender, sel, ptr )
    $stdout = out = StringIO.new  # Get standard output
    ret = do_it( sender, sel, ptr )
    $stdout = STDOUT              # It's important to restore $stdout otherwise you get an error
    @editor.appendText( "\n" + ret.inspect + "\n" + out.string )
  end

end

if __FILE__ == $0
  FXApp.new("Ruby Workspace", "Clear View Training") do |theApp|
    RubyWorkspaceMainWindow.new(theApp)
    theApp.create
    theApp.run
  end
end