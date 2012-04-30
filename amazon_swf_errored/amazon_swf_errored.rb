# Reports number of Amazon Simple Workflow processes that have closed with
# errors (failed, terminated or timed out).
#
# Steve Ims (steve_ims@yahoo.com)
class AmazonSWFErrored < Scout::Plugin
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
  EOS
  
  def init
    @access_key = option('access_key').to_s.strip
    if @access_key.empty?
      return error('access_key cannot be empty')
    end
    
    @secret_key = option('secret_key').to_s.strip
    if @secret_key.empty?
      return error('secret_key cannot be empty')
    end

    @swf_domain = option('swf_domain').to_s.strip
    if @swf_domain.empty?
      return error('swf_domain cannot be empty')
    end

    # SWF results are eventually consistent.  interval_rescan is a means to
    # recheck for late updates.
    @interval_rescan = option('interval_rescan').to_i

    nil
  end
  
  # Scout method
  def build_report
    return if init()

    if !@last_run
      # @last_run is not defined on the first invocation.
      # Use time of first invocation as hard limit: no checks before epoch.
      remember( :epoch => Time.now )

    else
      AWS.config(
        :access_key_id => @access_key,
        :secret_access_key => @secret_key
      )

      # http://docs.amazonwebservices.com/AWSRubySDK/latest/frames.html
      swf = AWS::SimpleWorkflow.new
      domain = swf.domains[@swf_domain]

      epoch = memory( :epoch )
      cutoff_time = [epoch, @last_run - @interval_rescan].max

      # Ensure that each errored workflow is not double counted.
      # key == run_id; value == closed_at
      failed_workflows = memory( :failed_workflows ) || {}

      # Remove outdated entries from the history.
      failed_workflows.delete_if { |k,v| v < cutoff_time }

      # Check for new errors.
      added = 0
      [:failed, :terminated, :timed_out].each do |status|
        # Use #each instead of #count to avoid truncation.
        each_options = {
          :status => status, 
          :closed_after => cutoff_time
        }
        domain.workflow_executions.each( each_options ) do |x|
          if !failed_workflows.has_key?( x.run_id )
            failed_workflows[ x.run_id ] = x.closed_at
            added += 1
          end
        end
      end

      remember( :failed_workflows => failed_workflows )
      remember( :epoch => epoch )
      report( :errored_workflows => added )
    end
  end
end
