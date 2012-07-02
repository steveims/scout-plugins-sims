# Reports number of Amazon Simple Workflow processes that have closed with
# errors (failed, terminated or timed out).
#
# Eric Knecht (eric@ericknecht.com)
class AmazonSWFZombie < Scout::Plugin
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
    interval_rescan:
      name: Interval rescan
      default: 3600
      notes: Additional interval scanned before @last_run (sec) to check for late updates.  Defaults to one hour.
    max_run_time:
      name: Max Run Time
      default: 1800
      notes: We will search for workflows that are running for more than @max_run_time. Defaults to 30m. 
  EOS
  
  def init
    @access_key = option('access_key') or return error('access_key cannot be empty')
    @secret_key = option('secret_key') or return error('secret_key cannot be empty')
    @swf_domain = option('swf_domain') or return error('swf_domain cannot be empty')
    @max_run_time = option('max_run_time').to_i or return error('max_run_time cannot be empty')

    # SWF results are eventually consistent.  interval_rescan is a means to
    # recheck for late updates.
    @interval_rescan = option('interval_rescan').to_i
    nil
  end
  
  # Scout method
  def build_report
    return if init

    AWS.config(
      :access_key_id => @access_key,
      :secret_access_key => @secret_key
    )

    # http://docs.amazonwebservices.com/AWSRubySDK/latest/frames.html
    swf = AWS::SimpleWorkflow.new
    domain = swf.domains[@swf_domain]

    zombie_workflows = 0
    total_workflows=0
    domain.workflow_executions.each(:status => :open) do |execution|
      unless execution.workflow_id.start_with? 'Cron'
        zombie_workflows +=1 if (Time.now.to_i - execution.started_at.to_i) > @max_run_time
        total_workflows +=1
      end
    end

    report( :zombie_workflows => zombie_workflows )
    report( :total_workflows => total_workflows )
  end
end
