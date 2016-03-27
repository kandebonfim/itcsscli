require "itcss_cli/version"
require "erb"
require 'fileutils'

module ItcssCli
  class Init

    ITCSS_DIR = "stylesheets"
    ITCSS_FILE_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_file.erb"))
    ITCSS_FILES = ["settings", "tools", "generic", "base", "objects", "components", "trumps"]

    def command_parser
      if ARGV[0] == 'init'                                   # $ itcss init

      elsif ARGV[0] == 'install' && ARGV[1] == 'example'     # $ itcss install example
        new_itcss_basic_structure
      elsif ARGV[0] == 'new' && ARGV[1] && ARGV[2]           # $ itcss new components buttons
        new_itcss_module(ARGV[1], ARGV[2])
      end
    end

    def new_itcss_basic_structure
      File.open ITCSS_FILE_TEMPLATE do |io|
        template = ERB.new io.read

        ITCSS_FILES.each do |file|
          new_itcss_file(file, 'example', template)
        end
      end
    end

    def new_itcss_module(type, file)
      File.open ITCSS_FILE_TEMPLATE do |io|
        template = ERB.new io.read
          new_itcss_file(type, file, template)
      end
    end

    def new_itcss_file(type, file, template)
      FileUtils.mkdir_p ITCSS_DIR
      FileUtils.mkdir_p "#{ITCSS_DIR}/#{type}"

      contents = "##{type}.#{file}"
      File.open "#{ITCSS_DIR}/#{type}/_#{type}.#{file}.sass", "w+" do |out|
        out.puts template.result binding
      end
    end

  end
end
