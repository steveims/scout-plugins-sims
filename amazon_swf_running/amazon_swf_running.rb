# Reports number of Amazon Simple Workflow processes that have closed with
# errors (failed, terminated or timed out).
#
# Eric Knecht (eric@ericknecht.com)
class AmazonSWFRunning < Scout::Plugin
  needs 'rubygems'
  needs 'aws-sdk'

  OPTIONS = <<-EOS
    access_key:
      name: AWS Access Key
      notes: Your Amazon Web Services access key (20-char alphanumeric)
    secret_key:
      name: AWS Secret
      notes: Your Amazon Web Services secret key (40-char alphanumeric)
    swf_domain:
      name: SWF Domain
      notes: Simple Workflow domain
    workflow_types:
      name: Workflow Types
      notes: Whitespace seperated list of workflows to ensure running
  EOS

  def init
    @access_key = option('access_key') or return error('access_key cannot be empty')
    @secret_key = option('secret_key') or return error('secret_key cannot be empty')
    @swf_domain = option('swf_domain') or return error('swf_domain cannot be empty')
    @workflow_types = option('workflow_types') or return error('workflow_types cannot be empty')
    @workflow_types = @workflow_types.split
    nil
  end

  # Scout method
  def build_report
    return if init

    AWS.config(
      :access_key_id => @access_key,
      :secret_access_key => @secret_key
    )

    # http://docs.amazonwebservices.com/AWSRubySDK/latest/frames.swf
    swf = AWS::SimpleWorkflow.new
    domain = swf.domains[@swf_domain]
    running_workflows = {}
    @workflow_types.each do |type|
        running_workflows[ type.to_sym ] = 0
    end

    domain.workflow_executions.each(:status => :open) do |execution|
      name = execution.workflow_type.name
      running_workflows[ name.to_sym ] =1   if @workflow_types.include? name
    end

    running_workflows.keys.each do |key|
      report key => running_workflows[key]
    end
  end
end
