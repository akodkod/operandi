# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe Operandi do
  describe "standalone loading" do
    it "loads without relying on other gems" do
      lib_path = File.expand_path("../../lib", __dir__)
      output, status = Open3.capture2e(
        RbConfig.ruby,
        "--disable-gems",
        "-I#{lib_path}",
        "-e",
        'require "operandi"',
      )

      expect(status).to be_success, output
    end
  end

  describe ".config" do
    it do
      Operandi::Config::DEFAULTS.each_key do |param|
        expect(described_class.config).to respond_to(param).and respond_to("#{param}=")
      end
    end
  end

  describe ".configure" do
    it do
      described_class.configure do |config|
        expect(config).to be_a(Operandi::Config)
      end
    end
  end
end
