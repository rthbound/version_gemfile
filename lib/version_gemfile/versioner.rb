require 'tempfile'

module VersionGemfile
  class Versioner
    attr_reader :lock_contents, :gemfile_content

    IS_GEM_LINE = /^\s* gem \s+ ['|"] /ix
    HAS_VERSION  = /^\s*gem \s+ ['|"] \s* [\w|-]+ \s* ['|"]\s*,\s*['|"]/ix
    GET_GEM_NAME = /^\s*gem \s+ ['|"] \s* ([\w|-]+) \s* ['|"]/ix
    GET_VERSION_NUMBER = /^\s+[\w|-]+ \s \( ([\w|\.]+) \)/ix

    def self.add_versions!
      new.add_versions
    end

    def initialize
      @lock_contents   = File.read("Gemfile.lock")
      @gemfile_content = File.readlines('Gemfile')
      @orig_gemfile = File.read("Gemfile")
    end

    #TODO: Clean this up!
    def add_versions
      new_gemfile = Tempfile.new("Gemfile.versioned")
      begin
        gemfile_content.each do |gem_line|
          if is_gem_line?(gem_line)
            new_gemfile.puts(build_gem_line(gem_line))
          else
            new_gemfile.puts(gem_line)
          end
        end
        File.truncate("Gemfile", 0)
        new_gemfile.rewind
        File.open("Gemfile", "w") {|f| f.write(new_gemfile.read)}
      rescue Exception => e
        puts "ERROR: #{e}"
        puts "Restoring Gemfile"
        File.open("Gemfile", "w") {|f| f.write(@orig_gemfile)}
      ensure
        new_gemfile.close
        new_gemfile.unlink
      end
    end

    def match_gem(gem_line)
      gem_line.match(HAS_VERSION)
    end

    def is_gem_line?(gem_line)
      gem_line =~ IS_GEM_LINE
    end

    def build_gem_line(gem_line, version = nil)
      return gem_line if gem_line.match(HAS_VERSION)
      gem_name = gem_line.match(GET_GEM_NAME) { $1 }
      spaces = gem_line.match(/^(\s+)/){ $1 }
      version ||= get_version(gem_name)
      "#{spaces}gem '#{gem_name}', '~> #{version}'"
    end

    private

    def get_version(gem_name)
      regexp = /^\s+#{gem_name}\s\(([\w|\.]+)\)/ix
      regexp.match(lock_contents) { $1 }
    end
  end
end