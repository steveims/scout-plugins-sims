# Template for a unit test of the AmazonSWFErrored plugin for Scout.
#
# Requires an AWS account with access to SWF.  Edit the source
#
# This test creates a workflow.
#
# Steve Ims (steve_ims@yahoo.com)

require 'test/unit'
require 'rubygems'
require 'scout'
require 'aws-sdk'
require File.dirname(__FILE__)+'/amazon_swf_zombie'

class AmazonSWFZombieTest < Test::Unit::TestCase
  def setup
    # Required values.
    @access_key = 'YOUR_ACCESS_KEY'
    @secret_key = 'YOUR_SECRET_KEY'
    @swf_domain = 'YOUR_SWF_DOMAIN'
    @swf_input =  'OPTIONAL_INPUT'

    @swf_name = 'FailWorldWorkflow.attemptGloriously'
    @swf_version = 'VERSION'
    
    @interval_rescan = 3600
    AWS.config(
      :access_key_id => @access_key,
      :secret_access_key => @secret_key
    )

    swf = AWS::SimpleWorkflow.new
    domain = swf.domains[@swf_domain]

    @swf_type = nil
    domain.workflow_types.each do |type|
      if (type.name == @swf_name) && (type.version == @swf_version)
        @swf_type = type
        break
      end
    end

    if !@swf_type
      @swf_type = domain.workflow_types.create(@swf_name, @swf_version,
        :default_task_list => 'no-task-list',
        :default_child_policy => :request_cancel,
        :default_task_start_to_close_timeout => 60,
        :default_execution_start_to_close_timeout => 60)
    end
  end

  def test_it
   

    memory = {}
    options = {
      'access_key' => @access_key,
      'secret_key' => @secret_key,
      'swf_domain' => @swf_domain,
      'interval_rescan' => @interval_rescan,
      'max_run_time' => 2
    }
    result = AmazonSWFZombie.new(nil, memory, options).run
    check_result result, [{:zombie_workflows => 0}, {:total_workflows => 0}]

    workflow_execution = @swf_type.start_execution :input => @swf_input
    sleep 5

    result = AmazonSWFZombie.new(nil, memory, options).run
    check_result result, [{:zombie_workflows => 1}, {:total_workflows => 1}]

  end

  def check_result(result, reports=[])
    assert_equal(reports, result[:reports], 'reports not equal')
    assert(result[:errors].empty?, 'errors not empty: ' + result[:errors].inspect)
    assert(result[:alerts].empty?, 'alerts not empty: ' + result[:alerts].inspect)
  end
end
