require "itcss_cli/version"
require "erb"
require 'fileutils'
require 'colorize'
require 'yaml'

module ItcssCli
  class Init

    ITCSS_CONFIG_FILE = 'itcss.yml'
    ITCSS_CONFIG_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_config.erb"))
    ITCSS_MODULE_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_module.erb"))
    ITCSS_APP_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_application.erb"))
    ITCSS_MODULES = ["requirements", "settings", "tools", "generic", "base", "objects", "components", "trumps"]
    ITCSS_FILES = {
      "requirements" => "Vendor libraries",
      "settings" => "Sass vars, etc.",
      "tools" => "Functions and mixins.",
      "generic" => "Generic, high-level styling, like resets, etc.",
      "base" => "Unclasses HTML elements (e.g. `h2`, `ul`).",
      "objects" => "Objects and abstractions.",
      "components" => "Your designed UI elements (inuitcss includes none of these).",
      "trumps" => "Overrides and helper classes."
    }

    ITCSS_COMMANDS = [
      "itcss init                       | Initiates itcss_cli configuration with a itcss.yml file. [start here]",
      "itcss install example            | Creates an example of ITCSS structure in path specified in itcss.yml.",
      "itcss new [module] [filename]    | Creates a new ITCSS module and automatically import it into imports file.",
      "itcss update                     | Updates the imports file using the files inside ITCSS structure.",
      "itcss help                       | Shows all available itcss commands and it's functions.",
      "itcss version                    | Shows itcss_cli gem version installed. [short-cut alias: '-v', 'v']"
    ]

    if File.exist?(ITCSS_CONFIG_FILE)
      ITCSS_CONFIG = YAML.load_file(ITCSS_CONFIG_FILE)
      ITCSS_CONFIG['stylesheets_directory'].nil? ? ITCSS_DIR = nil : ITCSS_DIR = ITCSS_CONFIG['stylesheets_directory']
      ITCSS_CONFIG['stylesheets_import_file'].nil? ? ITCSS_BASE_FILE = nil : ITCSS_BASE_FILE = ITCSS_CONFIG['stylesheets_import_file']
    else
      ITCSS_CONFIG = nil
    end

    def init_checker
      if ITCSS_CONFIG.nil?
        puts "There's no #{ITCSS_CONFIG_FILE} created yet. Run `itcss init` to create it.".red
        abort
      elsif ITCSS_DIR.nil? || ITCSS_BASE_FILE.nil?
        puts "Something is wrong with your itcss.yml file. Please delete it and run `itcss init` again.".red
        abort
      elsif ITCSS_DIR == 'TODO' || ITCSS_BASE_FILE == 'TODO'
        puts "You haven't done the itcss_cli's configuration. You must provide your directories settings in itcss.yml.".yellow
        abort
      end
    end

    def command_parser
      # $ itcss init
      if ARGV[0] == 'init'
        init_itcss_config_file


      # $ itcss install example
      elsif ARGV[0] == 'install' && ARGV[1] == 'example'
        init_checker
        new_itcss_basic_structure


      # $ itcss new||n [module] [filename]
      elsif ARGV[0] == 'new' && ARGV[1] && ARGV[2] || ARGV[0] == 'n' && ARGV[1] && ARGV[2]
        init_checker

        occur = ITCSS_MODULES.each_index.select{|i| ITCSS_MODULES[i].include? ARGV[1]}
        if occur.size == 1
          new_itcss_module(ITCSS_MODULES[occur[0]], ARGV[2])
        else
          puts "'#{ARGV[1]}' is not an ITCSS module. Try settings, tools, generic, base, objects, components or trumps.".red
          abort
        end


      # $ itcss help
      elsif ARGV[0] == 'help'
        itcss_help


      # $ itcss version
      elsif ARGV[0] == 'version' || ARGV[0] == '-v' || ARGV[0] == 'v'
        itcss_version
      end

      # $ itcss update
      if ARGV[0] == 'install' || ARGV[0] == 'new' || ARGV[0] == 'update'
        init_checker
        generate_base_file
      end
    end

    def init_itcss_config_file
      unless File.exist?(ITCSS_CONFIG_FILE)
        File.open ITCSS_CONFIG_TEMPLATE do |io|
          template = ERB.new io.read

          config_file = File.expand_path(File.join(File.dirname(__FILE__), '../templates/itcss_config.yml'))
          content = YAML.load_file(config_file).to_yaml

          File.open ITCSS_CONFIG_FILE, "w+" do |out|
            out.puts template.result binding
          end
        end
        puts "create #{ITCSS_CONFIG_FILE}".green
        puts "Well done! Please do your own configurations in itcss.yml.".yellow
      else
        puts "#{ITCSS_CONFIG_FILE} already exists.".red
        abort
      end
    end

    def new_itcss_basic_structure
      File.open ITCSS_MODULE_TEMPLATE do |io|
        template = ERB.new io.read

        ITCSS_MODULES.each do |file|
          new_itcss_file(file, 'example', template)
        end
      end
    end

    def new_itcss_module(type, file)
      File.open ITCSS_MODULE_TEMPLATE do |io|
        template = ERB.new io.read
        new_itcss_file(type, file, template)
      end
    end

    def new_itcss_file(type, file, template)
      FileUtils.mkdir_p ITCSS_DIR
      FileUtils.mkdir_p "#{ITCSS_DIR}/#{type}"
      FileUtils.chmod "u=wrx,go=rx", ITCSS_DIR

      file_path = "#{ITCSS_DIR}/#{type}/_#{type}.#{file}.sass"
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

    def generate_base_file
      FileUtils.mkdir_p ITCSS_DIR

      itcss_files_to_import = {}
      ITCSS_MODULES.each do |current_module|
        itcss_module_files = Dir[ File.join("#{ITCSS_DIR}/#{current_module}/", '**', '*') ].reject { |p| File.directory? p }
        itcss_files_to_import[current_module] = itcss_module_files.map{|s| s.gsub("#{ITCSS_DIR}/", '')}
      end

      file_path = "#{ITCSS_DIR}/#{ITCSS_BASE_FILE}.sass"
      contents = "#{ITCSS_BASE_FILE}.sass"
      File.open ITCSS_APP_TEMPLATE do |io|
        template = ERB.new io.read

        File.open file_path, "w+" do |out|
          out.puts template.result binding
        end
      end

      puts "update #{file_path}".blue
    end

    def itcss_help
      puts "itcss_cli available commmands:".yellow
      puts ITCSS_COMMANDS.map{|s| s.prepend("  ")}
    end

    def itcss_version
      puts VERSION
    end

  end
end
