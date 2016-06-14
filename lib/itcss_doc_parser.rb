def initialize_doc
  puts 'parsing your files...'.yellow

  @ITCSS_MODULES.each do |current_module|
    itcss_module_files = Dir[ File.join("#{@ITCSS_DIR}/#{current_module}/", '**', '*') ].reject { |p| File.directory? p }
    if itcss_module_files.kind_of?(Array) && itcss_module_files.any?
      module_header = construct_module_header current_module
      @all_files_markup = @all_files_markup.to_s + module_header
    end
    itcss_module_files.each do |current_file|
      map_file current_file
    end
  end

  construct_navigation
  write_itcss_map_file @all_files_markup, @nav
end

def map_file file
  File.open file do |io|
    get_lines_content io.read
  end

  selector_indexes = get_selector_indexes @line_type_indexes
  selector_blocks = get_selector_blocks @lines, selector_indexes
  file_markup = construct_file_markup selector_blocks, file
  @all_files_markup = @all_files_markup.to_s + file_markup
end

def get_lines_content content
  @lines, @line_type_indexes = [], []
  content.each_line.with_index do |line, index|
    line_content = get_line_content line
    (@lines ||= []).push line
    (@line_type_indexes ||= []).push line_content
    # puts "#{index}|#{line_content}|#{line}"
  end
end

def get_line_content line
  if line.chars.size <= 1
    "em" # empty
  elsif line.start_with? '/// '
    "sc" # super comment
  elsif line.start_with? '// '
    "rc" # regular comment
  elsif line.start_with? ' '
    "pr" # property
  else
    'sl' # selector
  end
end

def get_selector_type line
  if line.start_with? '='
    "mixin"
  elsif line.start_with? '$'
    "variable"
  elsif line.start_with? '@import'
    "import"
  elsif line.start_with? '@keyframes'
    "keyframes"
  elsif line.start_with? '%'
    "placeholder selector"
  elsif !line.include? '.'
    "unclassed"
  elsif line.include? '--'
    "modifier"
  elsif line.include? '__'
    "element"
  else
    "block"
  end
end

def get_selector_indexes line_type_indexes
  line_type_indexes.each_index.select{|x| line_type_indexes[x] == "sl"}
end

def get_selector_blocks lines, selector_indexes
  @selector_blocks = []
  selector_indexes.each_with_index do |index, i|
    (@selector_blocks ||= []).push lines[index..(selector_indexes[i+1] ? selector_indexes[i+1]-1 : lines.size)]
  end

  @selector_blocks
end

def construct_file_markup selector_blocks, file_name
  file_markup = "<div class='file' id='#{excerpt_filename file_name}'><div class='file__content'>"
  if selector_blocks.kind_of?(Array) && selector_blocks.any?
    selector_blocks.each do |selector_block|
      selector_type = get_selector_type selector_block.first
      file_markup += "<h3 data-type='#{selector_type}'>#{line_break_string selector_block.shift}</h3>"
      file_markup += "<pre><code class='language-sass'>#{line_break_array selector_block}</code></pre>"
    end
  else
    file_markup += "<div class='blank_slate'>Empty file :/</div>"
  end
  file_markup += "</div></div>"

  file_markup
end

def construct_module_header module_name
  "<div id='#{module_name}' class='module'>#{module_name}</div>"
end

def construct_navigation
  @nav = '<div class="nav">'
  @ITCSS_MODULES.each do |current_module|
    itcss_module_files = Dir[ File.join("#{@ITCSS_DIR}/#{current_module}/", '**', '*') ].reject { |p| File.directory? p }
    if itcss_module_files.kind_of?(Array) && itcss_module_files.any?
      @nav += "<a href='##{current_module}' class='nav__item'>#{current_module}</a>"
      itcss_module_files.each do |current_file|
        @nav += "<a href='##{excerpt_filename current_file}' class='nav__item nav__link'>#{excerpt_filename(current_file).split('.')[1]}</a>"
      end
    end
  end
  @nav += '</div>'
end

def write_itcss_map_file content, nav
  File.open @ITCSS_DOC_TEMPLATE do |io|
    template = ERB.new io.read
    logo = line_break_removal File.open(relative_file_path('../assets/logo_doc.svg')).read
    style = line_break_removal File.open(relative_file_path('../assets/itcss.css')).read
    javascript = line_break_removal File.open(relative_file_path('../assets/itcss.js')).read

    FileUtils.mkdir_p @ITCSS_DOC_DIR
    File.open @ITCSS_DOC_FILE, "w+" do |out|
      out.puts template.result binding
    end

    puts "The documentation has been successfully generated.".green
    puts "create #{@ITCSS_DOC_FILE}".green
    puts "opening #{@ITCSS_DOC_FILE}...".yellow
    `open #{@ITCSS_DOC_FILE}`
  end
end

# Helper
def excerpt_filename file
  File.basename(file, ".*").sub('_', '')
end

def line_break_array content
  content.map{ |p| p.sub("\n", '&#10;') }.join
end

def line_break_string content
  content.sub "\n", '&#10;'
end

def line_break_removal content
  content.sub "\n", ''
end
