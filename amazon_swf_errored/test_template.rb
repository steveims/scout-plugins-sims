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
require File.dirname(__FILE__)+'/amazon_swf_errored'

class AmazonSWFErroredTest < Test::Unit::TestCase
  def setup
    # Required values.
    @access_key = 'YOUR_ACCESS_KEY'
    @secret_key = 'YOUR_SECRET_KEY'
    @swf_domain = 'YOUR_SWF_DOMAIN'

    @interval_rescan = 3600
    @swf_name = 'test-amazon-swf-errored'
    @swf_version = '1'

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
        :default_task_start_to_close_timeout => 1,
        :default_execution_start_to_close_timeout => 1)
    end
  end

  def test_it
    # Create one errored execution before first Scout scan.
    # Expect this error will not be counted.
    workflow_execution = @swf_type.start_execution
    sleep(5)

    memory = {}
    options = {
      'access_key' => @access_key,
      'secret_key' => @secret_key,
      'swf_domain' => @swf_domain,
      'interval_rescan' => @interval_rescan
    }

    result = AmazonSWFErrored.new(nil, memory, options).run
    check_result( result )

    workflow_execution = @swf_type.start_execution
    sleep(5)

    result = AmazonSWFErrored.new(Time.now, result[:memory], options).run
    check_result( result, [:errored_workflows => 1] )
    
    workflow_execution = @swf_type.start_execution
    workflow_execution = @swf_type.start_execution
    sleep(5)

    result = AmazonSWFErrored.new(Time.now, result[:memory], options).run
    check_result( result, [:errored_workflows => 2] )
  end

  def check_result(result, reports=[])
    puts result.inspect

    assert_not_nil(result[:memory][:epoch], 'Missing epoch.')
    assert_equal(reports, result[:reports], 'reports not equal')
    assert(result[:errors].empty?, 'errors not empty: ' + result[:errors].inspect)
    assert(result[:alerts].empty?, 'alerts not empty: ' + result[:alerts].inspect)
  end
end
