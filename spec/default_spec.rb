require "chefspec"
require ::File.join ::File.dirname(__FILE__), "..", "libraries", "default"

describe ::Openstack do
  before do
    @chef_run = ::ChefSpec::ChefRunner.new do |n|
      n.set['mysql'] = {}
      n.set['mysql']['server_root_password'] = "password"
    end
    @chef_run.converge "openstack-common::default"
    @subject = ::Object.new.extend(::Openstack)
  end

  describe "#endpoint" do
    it "returns nil when no openstack.endpoints not in node attrs" do
      @subject.instance_variable_set :@node, {}
      @subject.endpoint("nonexisting").should be_nil
    end
    it "returns nil when no such endpoint was found" do
      @subject.instance_variable_set :@node, @chef_run.node
      @subject.endpoint("nonexisting").should be_nil
    end
    it "handles a URI needing escaped" do
      uri_hash = {
        "openstack" => {
          "endpoints" => {
            "compute-api" => {
              "uri" => "http://localhost:8080/v2/%(tenant_id)s"
            }
          }
        }
      }
      @subject.instance_variable_set :@node, uri_hash
      result = @subject.endpoint "compute-api"
      result.path.should == "/v2/%25(tenant_id)s"
    end
    it "returns endpoint URI object when uri key in endpoint hash" do
      uri_hash = {
        "openstack" => {
          "endpoints" => {
            "compute-api" => {
              "uri" => "http://localhost:8080/path"
            }
          }
        }
      }
      @subject.instance_variable_set :@node, uri_hash
      result = @subject.endpoint "compute-api"
      result.port.should == 8080
    end
    it "returns endpoint URI string when uri key in endpoint hash and host also in hash" do
      uri_hash = {
        "openstack" => {
          "endpoints" => {
            "compute-api" => {
              "uri" => "http://localhost",
              "host" => "ignored"
            }
          }
        }
      }
      @subject.instance_variable_set :@node, uri_hash
      @subject.endpoint("compute-api").to_s.should eq "http://localhost"
    end
    it "returns endpoint URI object when uri key not in endpoint hash but host is in hash" do
      uri_hash = {
        "openstack" => {
          "endpoints" => {
            "compute-api" => {
              "host" => "localhost",
              "port" => "8080"
            }
          }
        }
      }
      @subject.instance_variable_set :@node, uri_hash
      result = @subject.endpoint "compute-api"
      result.port.should == 8080
    end
  end

  describe "#endpoints" do
    it "does nothing when no endpoints" do
      @subject.instance_variable_set :@node, {}
      @subject.endpoints.should be_nil
    end
    it "does nothing when empty endpoints" do
      @subject.instance_variable_set :@node, {"openstack" => { "endpoints" => {}}}
      @count = 0
      @subject.endpoints do | ep |
        @count += 1
      end
      @count.should eq 0
    end
    it "executes block count when have endpoints" do
      @subject.instance_variable_set :@node, @chef_run.node
      @count = 0
      @subject.endpoints do |ep|
        @count += 1
      end
      @count.should >= 1
    end
  end

  describe "#db" do
    it "returns nil when no openstack.db not in node attrs" do
      @subject.instance_variable_set :@node, {}
      @subject.db("nonexisting").should be_nil
    end
    it "returns nil when no such service was found" do
      @subject.instance_variable_set :@node, @chef_run.node
      @subject.db("nonexisting").should be_nil
    end
    it "returns db info hash when service found" do
      @subject.instance_variable_set :@node, @chef_run.node
      @subject.db("compute")['host'].should == "127.0.0.1"
      @subject.db("compute").has_key?("uri").should be_false
    end
  end

  describe "#db_uri" do
    it "returns nil when no openstack.db not in node attrs" do
      @subject.instance_variable_set :@node, {}
      @subject.db_uri("nonexisting", "user", "pass").should be_nil
    end
    it "returns nil when no such service was found" do
      @subject.instance_variable_set :@node, @chef_run.node
      @subject.db_uri("nonexisting", "user", "pass").should be_nil
    end
    it "returns db info hash when service found" do
      @subject.instance_variable_set :@node, @chef_run.node
      expect = "mysql://user:pass@127.0.0.1:3306/nova"
      @subject.db_uri("compute", "user", "pass").should eq expect
    end
  end

  describe "#db_create_with_user" do
    it "returns nil when no openstack.db not in node attrs" do
      @subject.instance_variable_set :@node, {}
      @subject.db_create_with_user("nonexisting", "user", "pass").should be_nil
    end
    it "returns nil when no such service was found" do
      @subject.instance_variable_set :@node, @chef_run.node
      @subject.db_create_with_user("nonexisting", "user", "pass").should be_nil
    end
    it "returns db info and creates database with user when service found" do
      @subject.stub(:database).and_return {}
      @subject.stub(:database_user).and_return {}
      @subject.instance_variable_set :@node, @chef_run.node
      result = @subject.db_create_with_user("compute", "user", "pass")
      result['host'].should eq "127.0.0.1"
      result['port'].should eq "3306"
    end
  end
end