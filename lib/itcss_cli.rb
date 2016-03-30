require "itcss_cli/version"
require "erb"
require 'fileutils'
require 'colorize'
require 'yaml'

module ItcssCli
  class Init

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

      @ITCSS_COMMANDS_DESCRIPTION = [
        "             COMMAND            ALIAS                               FUNCTION                                 ",
        "itcss init                    |       | Initiates itcss_cli configuration with a itcss.yml file. [start here]",
        "itcss install [filenames]     |       | Creates an example of ITCSS structure in path specified in itcss.yml.",
        "itcss new [module] [filename] |   n   | Creates a new ITCSS module and automatically import it into imports file.",
        "itcss update                  |   u   | Updates the imports file using the files inside ITCSS structure.",
        "itcss help                    | h, -h | Shows all available itcss commands and it's functions.",
        "itcss version                 | v, -v | Shows itcss_cli gem version installed."
      ]

      @ITCSS_COMMANDS = ['init', 'install', 'new', 'n', 'update', 'u', 'help', 'h', '-h', 'version', 'v', '-v']

      if File.exist?(@ITCSS_CONFIG_FILE)
        @ITCSS_CONFIG = YAML.load_file(@ITCSS_CONFIG_FILE)
        @ITCSS_DIR ||= @ITCSS_CONFIG['stylesheets_directory']
        @ITCSS_BASE_FILE ||= @ITCSS_CONFIG['stylesheets_import_file']
        @ITCSS_PACKAGE_MANAGEMENT ||= @ITCSS_CONFIG['package_management']
      else
        @ITCSS_CONFIG = nil
      end
    end

    def command_parser
      # Not a valid command
      unless @ITCSS_COMMANDS.include? ARGV[0]
        puts "#{current_full_command} is not a valid command. Check out the available commands:".red
        itcss_help
      end

      # $ itcss init
      if 'init' == ARGV[0]
        itcss_init


      # $ itcss install example
      elsif 'install' == ARGV[0]
        itcss_init_checker
        itcss_install(ARGV[1])


      # $ itcss new||n [module] [filename]
      elsif ['new', 'n'].include? ARGV[0] && ARGV[1] && ARGV[2]
        itcss_init_checker

        occur = @ITCSS_MODULES.each_index.select{|i| @ITCSS_MODULES[i].include? ARGV[1]}
        if occur.size == 1
          itcss_new_module(@ITCSS_MODULES[occur[0]], ARGV[2])
        else
          puts "'#{ARGV[1]}' is not an ITCSS module. Try settings, tools, generic, base, objects, components or trumps.".red
          abort
        end


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
      unless File.exist?(@ITCSS_CONFIG_FILE)
        File.open @ITCSS_CONFIG_TEMPLATE do |io|
          template = ERB.new io.read

          config_file = File.expand_path(File.join(File.dirname(__FILE__), '../templates/itcss_config.yml'))
          content = YAML.load_file(config_file).to_yaml

          File.open @ITCSS_CONFIG_FILE, "w+" do |out|
            out.puts template.result binding
          end
        end
        puts "create #{@ITCSS_CONFIG_FILE}".green
        puts "Well done! Please do your own configurations in itcss.yml.".yellow
      else
        puts "#{@ITCSS_CONFIG_FILE} already exists.".red
        abort
      end
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
        current_inuit_modules = @ITCSS_CONFIG["inuit_modules"].select{ |p| p.include? current_module }
        itcss_files_to_import[current_module] = current_inuit_modules.map{ |p| inuit_imports_path p }

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
      puts "itcss_cli available commmands:".yellow
      puts @ITCSS_COMMANDS_DESCRIPTION.map{|s| s.prepend("  ")}
    end

    def itcss_version
      puts VERSION
    end

    # Helper Methods
    def inuit_imports_path(filename)
      frags = filename.split(".")
      return "inuit-#{frags[1]}/#{filename}"
    end

    def itcss_init_checker
      if @ITCSS_CONFIG.nil?
        puts "There's no #{@ITCSS_CONFIG_FILE} created yet. Run `itcss init` to create it.".red
        abort
      elsif @ITCSS_DIR.nil? || @ITCSS_BASE_FILE.nil?
        puts "Something is wrong with your itcss.yml file. Please delete it and run `itcss init` again.".red
        abort
      elsif @ITCSS_DIR == 'TODO' || @ITCSS_BASE_FILE == 'TODO'
        puts "You haven't done the itcss_cli's configuration. You must provide your directories settings in itcss.yml.".yellow
        abort
      end
    end

    def relative_file_path(filename)
      File.expand_path(File.join(File.dirname(__FILE__), filename))
    end

    def current_full_command
      "`itcss_cli #{ARGV.join(' ')}`"
    end

  end
end
