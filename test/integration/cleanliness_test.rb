require_relative '../test_helper'

# kitchen sink for 1-off tests
describe "cleanliness" do
  def check_content(files)
    bad = files.map do |f|
      error = yield File.read(f)
      "#{f}: #{error}" if error
    end.compact
    bad.must_equal [], bad.join("\n")
  end

  let(:all_tests) { Dir["{,plugins/*/}test/controllers/**/*_test.rb"] }

  it "does not have boolean limit 1 in schema since this breaks mysql" do
    File.read("db/schema.rb").wont_match /\st\.boolean.*limit: 1/
  end

  it "does not include rails-assets-bootstrap" do
    # make sure rails-assets-bootstrap did not get included by accident (dependency of some other bootstrap thing)
    # if it is not avoidable see http://stackoverflow.com/questions/7163264
    File.read('Gemfile.lock').wont_include 'rails-assets-bootstrap '
  end

  if ENV['USE_UTF8MB4'] && ActiveRecord::Base.connection.adapter_name == "Mysql2"
    it "uses the right row format in mysql" do
      status = ActiveRecord::Base.connection.execute('show table status').to_a
      refute_empty status
      status.each do |table|
        table[3].must_equal "Dynamic"
      end
    end
  end

  it "does not use let(:user) inside of a as_xyz block" do
    check_content all_tests do |content|
      if content.include?("  as_") && content.include?("let(:user)")
        "uses as_xyz and let(:user) these do not mix!"
      end
    end
  end

  it "does not have actions on base controller" do
    found = ApplicationController.action_methods.to_a
    found.reject { |a| a =~ /^(_conditional_callback_around_|_callback_before_)/ } - ["flash"]
    found.must_equal []
  end

  it "has coverage" do
    files = Dir["{,plugins/*/}test/**/*_test.rb"]
    check_content files do |content|
      if content !~ /SingleCov.(not_)?covered\!/
        "needs to use SingleCov.covered!"
      end
    end
  end

  it "does not use setup/teardown" do
    check_content all_tests do |content|
      if content =~ /\s+(setup|teardown)[\s\{]/
        "uses setup or teardown, but should use before or after"
      end
    end
  end

  it "uses active test case wording" do
    check_content all_tests do |content|
      if content =~ /\s+it ['"]should /
        "uses `it should` working, please use active working `it should activate` -> `it activates`"
      end
    end
  end
end
