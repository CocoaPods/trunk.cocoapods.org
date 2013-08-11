require 'app/models/submission_job'

Sequel.migration do
  up do
    Pod::TrunkApp::SubmissionJob.each do |job|
      if job.travis_build_url
        job[:travis_build_id] = File.basename(job.travis_build_url).to_i
        job.save
      end
    end
  end

  down do
  end
end


