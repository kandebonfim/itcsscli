require "itcsscli/version"
require "erb"
require 'colorize'
require 'yaml'
require 'readline'
require 'fileutils'

# autocomplete config
Readline.completion_append_character = ""
Readline.completion_proc = Proc.new do |str|
  Dir[str + '*'].grep( /^#{Regexp.escape(str)}/ )
end

module Itcsscli
  class Core

    def initialize
      @ITCSS_CONFIG_FILE = 'itcss.yml'
      @ITCSS_CONFIG_TEMPLATE = relative_file_path "../templates/itcss_config.erb"
      @ITCSS_MODULE_TEMPLATE = relative_file_path "../templates/itcss_module.erb"
      @ITCSS_APP_TEMPLATE = relative_file_path "../templates/itcss_application.erb"
      @ITCSS_MODULES = ["requirements", "settings", "tools", "generic", "base", "objects", "components", "trumps"]
      @ITCSS_FILES = {
        "requirements" => "Vendor libraries",
        "settings" => "Sass vars, etc.",
        "tools" => "Functions and mixins.",
        "generic" => "Generic, high-level styling, like resets, etc.",
        "base" => "Unclasses HTML elements (e.g. `h2`, `ul`).",
        "objects" => "Objects and abstractions.",
        "components" => "Your designed UI elements (inuitcss includes none of these).",
        "trumps" => "Overrides and helper classes."
      }

      @ITCSS_COMMANDS = ['init', 'install', 'new', 'n', 'inuit', 'update', 'u', 'help', 'h', '-h', 'version', 'v', '-v']

      @ITCSS_COMMANDS_DESCRIPTION = [
        "             COMMAND                  ALIAS                               FUNCTION                                 ",
        "itcss init                          |       | Initiates itcsscli configuration with a #{@ITCSS_CONFIG_FILE} file. [start here]",
        "itcss install [filenames]           |       | Creates an example of ITCSS structure in path specified in #{@ITCSS_CONFIG_FILE}.",
        "itcss new [module] [filename]       |   n   | Creates a new ITCSS module and automatically import it into imports file.",
        "itcss inuit new [inuit module]      |inuit n| Add specified inuit module as an itcss dependency.",
        "itcss inuit help                    |inuit h| Add specified inuit module as an itcss dependency.",
        "itcss update                        |   u   | Updates the imports file using the files inside ITCSS structure.",
        "itcss help                          | h, -h | Shows all available itcss commands and it's functions.",
        "itcss version                       | v, -v | Shows itcsscli gem version installed."
      ]

      if File.exist?(@ITCSS_CONFIG_FILE)
        @ITCSS_CONFIG = YAML.load_file(@ITCSS_CONFIG_FILE)
        @ITCSS_DIR ||= @ITCSS_CONFIG['stylesheets_directory']
        @ITCSS_BASE_FILE ||= @ITCSS_CONFIG['stylesheets_import_file']
      else
        @ITCSS_CONFIG = nil
      end

      if File.exist?(@ITCSS_CONFIG_FILE) && @ITCSS_CONFIG['package_manager']
        @ITCSS_PACKAGE_MANAGER ||= @ITCSS_CONFIG['package_manager']
        @INUIT_MODULES ||= @ITCSS_CONFIG['inuit_modules']
      else
        @ITCSS_PACKAGE_MANAGER = nil
      end

      @INUIT_AVAILABLE_MODULES_FILE = relative_file_path "../data/inuit_modules.yml"
      @INUIT_AVAILABLE_MODULES = YAML.load_file(@INUIT_AVAILABLE_MODULES_FILE)
    end

    # ITCSS
    def command_parser
      # Not a valid command
      unless @ITCSS_COMMANDS.include? ARGV[0]
        not_a_valid_command
      end

      # $ itcss init
      if 'init' == ARGV[0]
        itcss_init


      # $ itcss install example
      elsif 'install' == ARGV[0]
        itcss_init_checker
        itcss_install(ARGV[1])


      # $ itcss new||n [module] [filename]
      elsif ['new', 'n'].include? ARGV[0]
        if find_valid_module ARGV[1]
          if ARGV[2]
            itcss_init_checker
            itcss_new_module(find_valid_module(ARGV[1]), ARGV[2])
          else
            not_a_valid_command
          end
        else
          not_a_valid_command
        end

      # $ itcss inuit||i [module] [filename]
      elsif 'inuit' == ARGV[0]
        inuit_command_parser


      # $ itcss help
      elsif ['help', '-h', 'h'].include? ARGV[0]
        itcss_help


      # $ itcss version
      elsif ['version', '-v', 'v'].include? ARGV[0]
        itcss_version
      end


      # $ itcss update
      if ['install', 'new', 'n', 'update', 'u'].include? ARGV[0]
        itcss_init_checker
        itcss_update_import_file
      end
    end

    def itcss_init
      if File.exist?(@ITCSS_CONFIG_FILE)
        puts "There is already a #{@ITCSS_CONFIG_FILE} created.".yellow
        puts "Do you want to override it?"
        user_override_itcss_yml = Readline.readline '[ y / n ] > '
        unless user_override_itcss_yml == 'y'
          abort
        end
      end

      init_config = {}

      puts "Well done! Let's configure your #{@ITCSS_CONFIG_FILE}:".yellow

      puts "Provide the root folder name where the ITCSS file structure should be built:"
      user_itcss_dir = Readline.readline '> '
      init_config['stylesheets_directory'] = user_itcss_dir

      puts "What is the name of your base sass file? (all ITCSS modules will be imported into it)"
      user_itcss_base_file = Readline.readline '> '
      init_config['stylesheets_import_file'] = user_itcss_base_file

      puts "Are you using a package manager?"
      user_itcss_package_manager = Readline.readline '[ y / n ] > '
      if user_itcss_package_manager == 'y'
        user_package_manager = true
      end

      if user_package_manager == true
        puts "Choose your package manager:"
        user_package_manager = Readline.readline '[ bower / npm ] > '

        unless ['bower', 'npm'].include? user_package_manager
          puts "#{user_package_manager} is not a valid package manager".red
          abort
        end

        init_config['package_manager'] = user_package_manager
      end

      File.open @ITCSS_CONFIG_TEMPLATE do |io|
        template = ERB.new io.read
        content = init_config.to_yaml

        File.open @ITCSS_CONFIG_FILE, "w+" do |out|
          out.puts template.result binding
        end
      end
      puts "#{@ITCSS_CONFIG_FILE} successfully created!".green
    end

    def itcss_install(filename)
      File.open @ITCSS_MODULE_TEMPLATE do |io|
        template = ERB.new io.read

        @ITCSS_MODULES.each do |file|
          itcss_new_file(file, filename, template)
        end
      end
    end

    def itcss_new_module(type, file)
      File.open @ITCSS_MODULE_TEMPLATE do |io|
        template = ERB.new io.read
        itcss_new_file(type, file, template)
      end
    end

    def itcss_new_file(type, file, template)
      FileUtils.mkdir_p @ITCSS_DIR
      FileUtils.mkdir_p "#{@ITCSS_DIR}/#{type}"
      FileUtils.chmod "u=wrx,go=rx", @ITCSS_DIR

      file_path = "#{@ITCSS_DIR}/#{type}/_#{type}.#{file}.sass"
      unless File.exist?(file_path)
        contents = "##{type}.#{file}"
        File.open file_path, "w+" do |out|
          out.puts template.result binding
        end
        puts "create #{file_path}".green
      else
        puts "#{file_path} is already created. Please delete it if you want it to be rewritten.".red
        abort
      end
    end

    def itcss_update_import_file
      FileUtils.mkdir_p @ITCSS_DIR

      itcss_files_to_import = {}
      @ITCSS_MODULES.each do |current_module|
        itcss_files_to_import[current_module] = []

        if @INUIT_MODULES
          itcss_files_to_import[current_module] += inuit_find_modules(current_module)
        end

        itcss_module_files = Dir[ File.join("#{@ITCSS_DIR}/#{current_module}/", '**', '*') ].reject { |p| File.directory? p }
        itcss_files_to_import[current_module] += itcss_module_files.map{|s| s.gsub("#{@ITCSS_DIR}/", '')}
      end

      file_path = "#{@ITCSS_DIR}/#{@ITCSS_BASE_FILE}.sass"
      contents = "#{@ITCSS_BASE_FILE}.sass"
      File.open @ITCSS_APP_TEMPLATE do |io|
        template = ERB.new io.read

        File.open file_path, "w+" do |out|
          out.puts template.result binding
        end
      end

      puts "update #{file_path}".blue
    end

    def itcss_help
      puts "itcsscli available commmands:".yellow
      puts @ITCSS_COMMANDS_DESCRIPTION.map{|s| s.prepend("  ")}
    end

    def itcss_version
      puts VERSION
    end

    # Helper Methods
    def itcss_init_checker
      if @ITCSS_CONFIG.nil?
        puts "There's no #{@ITCSS_CONFIG_FILE} created yet. Run `itcss init` to create it.".red
        abort
      elsif @ITCSS_DIR.nil? || @ITCSS_BASE_FILE.nil?
        puts "Something is wrong with your #{@ITCSS_CONFIG_FILE} file. Please run `itcss init` again to override it.".red
        abort
      end
    end

    def relative_file_path(filename)
      File.expand_path(File.join(File.dirname(__FILE__), filename))
    end

    def current_full_command
      "`itcss #{ARGV.join(' ')}`"
    end

    def not_a_valid_command
      puts "#{current_full_command} is not a valid command. Check out the available commands:".red
      if 'inuit' == ARGV[0]
        inuit_help
      else
        itcss_help
      end
      abort
    end

    def find_valid_module(arg)
      occur = @ITCSS_MODULES.each_index.select{|i| @ITCSS_MODULES[i].include? arg}
      if occur.size == 1
        return @ITCSS_MODULES[occur[0]]
      else
        puts "'#{arg}' is not an ITCSS module. Try #{@ITCSS_MODULES.join(', ')}.".red
        abort
      end
    end

    # INUIT
    def inuit_command_parser
      if @ITCSS_PACKAGE_MANAGER.nil?
        puts "You didn't choose a package manager. Please do it in #{@ITCSS_CONFIG_FILE}".red
        abort
      end

      # $ itcss inuit new [inuit module]
      if ['new', 'n'].include? ARGV[1]
        if ARGV[2] && inuit_find_valid_module(ARGV[2])
          itcss_init_checker
          inuit_module_name_frags = ARGV[2].split('.')
          inuit_new_module(inuit_module_name_frags[0], inuit_module_name_frags[1], inuit_find_valid_module(ARGV[2]))
        else
          not_a_valid_command
        end

      # $ itcss inuit help
      elsif ['help', 'h', '-h'].include? ARGV[1]
        inuit_help
      end

      # $ itcss update
      if ['new', 'n'].include? ARGV[1]
        itcss_update_import_file
      end
    end

    def inuit_new_module(c_module, file, module_object)
      if file
        current_module_name = inuit_module_fullname(c_module, file)
        current_config = YAML.load_file(@ITCSS_CONFIG_FILE)

        if current_config['inuit_modules'].nil?
          current_config['inuit_modules'] = []
        end

        current_config['inuit_modules'] << current_module_name

        unless current_config['inuit_modules'].uniq.length == current_config['inuit_modules'].length
          puts "#{current_module_name} is already added to #{@ITCSS_CONFIG_FILE}.".yellow
          abort
        end

        current_config['inuit_modules'].uniq!

        File.open @ITCSS_CONFIG_TEMPLATE do |io|
          template = ERB.new io.read
          content = current_config.to_yaml

          File.open @ITCSS_CONFIG_FILE, "w+" do |out|
            out.puts template.result binding
          end
        end

        @INUIT_MODULES = current_config['inuit_modules']

        puts "using #{@ITCSS_PACKAGE_MANAGER} to install inuit '#{current_module_name}' dependency...".green
        output = `#{@ITCSS_PACKAGE_MANAGER} install --save #{module_object['slug']}`
        puts output

        puts "update #{@ITCSS_CONFIG_FILE}. [added #{current_module_name}]".blue
      end
    end

    def inuit_help
      puts "itcss inuit available commmands:".yellow
      puts "  COMMAND                                   | #{@ITCSS_PACKAGE_MANAGER.upcase} EQUIVALENT"
      puts @INUIT_AVAILABLE_MODULES.map { |e| "  itcss inuit new #{e[0]}"+" "*(26-e[0].size)+"| "+e[1]['slug']  }
      puts "You can check all of these repositories at https://github.com/inuitcss/[inuit module].".yellow
      abort
    end

    # Inuit Helper Methods
    def inuit_find_modules(current_module)
      current_config = YAML.load_file(@ITCSS_CONFIG_FILE)
      current_inuit_modules = current_config["inuit_modules"].select{ |p| p.include? current_module }
      current_inuit_modules.map{ |p| inuit_imports_path p }
    end

    def inuit_find_valid_module(c_module)
      valid_module = @INUIT_AVAILABLE_MODULES[c_module]
      unless valid_module.nil?
        valid_module
      end
    end

    def inuit_module_fullname(c_module, filename)
      "#{c_module}.#{filename}"
    end

    def inuit_imports_path(filename)
      @ITCSS_PACKAGE_MANAGER == 'bower' ? package_manager_prefix = 'bower_components' : package_manager_prefix = 'node_modules'
      frags = filename.split(".")
      "#{package_manager_prefix}/inuit-#{frags[1]}/#{filename}"
    end

  end
end
