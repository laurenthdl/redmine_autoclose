require File.expand_path('../../test_helper', __FILE__)

class AutoclosePreviewTest < ActionDispatch::IntegrationTest
  fixtures :projects, :issue_statuses, :trackers, :users

  def setup
    @project_a = projects(:project_a)
    @project_b = projects(:project_b)
    
    @tracker_bug = Tracker.find_or_create_by(name: 'Bug') do |t|
      t.name = 'Bug'
    end
    @tracker_feature = Tracker.find_or_create_by(name: 'Feature') do |t|
      t.name = 'Feature'
    end
    
    @status_new = IssueStatus.find_or_create_by(name: 'New') do |s|
      s.name = 'New'
      s.is_closed = false
    end
    @status_resolved = IssueStatus.find_or_create_by(name: 'Resolved') do |s|
      s.name = 'Resolved'
      s.is_closed = false
    end
    @status_closed = IssueStatus.find_or_create_by(name: 'Closed') do |s|
      s.name = 'Closed'
      s.is_closed = true
    end
    
    @tracker_bug.save!
    @tracker_feature.save!
    @status_new.save!
    @status_resolved.save!
    @status_closed.save!
    
    @user = users(:users_001)
    
    @issue_12 = Issue.create!(
      id: 12,
      subject: 'Issue 12 - Should be selected',
      project: @project_a,
      tracker: @tracker_bug,
      status: @status_resolved,
      author: @user,
      created_on: 40.days.ago,
      updated_on: 40.days.ago
    )
    
    @issue_15 = Issue.create!(
      id: 15,
      subject: 'Issue 15 - Should not be selected',
      project: @project_a,
      tracker: @tracker_feature,
      status: @status_resolved,
      author: @user,
      created_on: 40.days.ago,
      updated_on: 40.days.ago
    )
    
    @issue_16 = Issue.create!(
      id: 16,
      subject: 'Issue 16 - Project B',
      project: @project_b,
      tracker: @tracker_bug,
      status: @status_resolved,
      author: @user,
      created_on: 40.days.ago,
      updated_on: 40.days.ago
    )
    
    add_journal(@issue_12, @status_resolved, 35.days.ago)
    add_journal(@issue_15, @status_resolved, 35.days.ago)
    add_journal(@issue_16, @status_resolved, 35.days.ago)
    
    if @issue_12.autoclose_issue.nil?
      AutocloseIssue.create!(issue: @issue_12, autoclose: true)
    end
    if @issue_15.autoclose_issue.nil?
      AutocloseIssue.create!(issue: @issue_15, autoclose: true)
    end
    if @issue_16.autoclose_issue.nil?
      AutocloseIssue.create!(issue: @issue_16, autoclose: true)
    end
  end

  test "issue 12 in project A should be selected for autoclose" do
    Setting.plugin_redmine_autoclose = {
      'autoclose_active' => '1',
      'autoclose_projects' => 'project-a',
      'autoclose_resolved_status_ids' => [@status_resolved.id.to_s],
      'autoclose_closed_status_id' => @status_closed.id.to_s,
      'autoclose_tracker_ids' => [@tracker_bug.id.to_s],
      'autoclose_interval' => '30'
    }
    
    config = RedmineAutoclose::Config.new
    issues_found = []
    
    RedmineAutoclose::Autoclose.enumerate_issues(config, false) do |issue, when_resolved|
      issues_found << issue
    end
    
    assert_includes issues_found, @issue_12, "Issue 12 from project A with Bug tracker should be found"
  end

  test "issue 15 in project A should not be selected due to tracker" do
    Setting.plugin_redmine_autoclose = {
      'autoclose_active' => '1',
      'autoclose_projects' => 'project-a',
      'autoclose_resolved_status_ids' => [@status_resolved.id.to_s],
      'autoclose_closed_status_id' => @status_closed.id.to_s,
      'autoclose_tracker_ids' => [@tracker_bug.id.to_s],
      'autoclose_interval' => '30'
    }
    
    config = RedmineAutoclose::Config.new
    issues_found = []
    
    RedmineAutoclose::Autoclose.enumerate_issues(config, false) do |issue, when_resolved|
      issues_found << issue
    end
    
    assert_not_includes issues_found, @issue_15, "Issue 15 with Feature tracker should not be found"
  end

  test "issue 16 in project B should not be selected due to project" do
    Setting.plugin_redmine_autoclose = {
      'autoclose_active' => '1',
      'autoclose_projects' => 'project-a',
      'autoclose_resolved_status_id' => [@status_resolved.id.to_s],
      'autoclose_closed_status_id' => @status_closed.id.to_s,
      'autoclose_tracker_ids' => [@tracker_bug.id.to_s],
      'autoclose_interval' => '30'
    }
    
    config = RedmineAutoclose::Config.new
    issues_found = []
    
    RedmineAutoclose::Autoclose.enumerate_issues(config, false) do |issue, when_resolved|
      issues_found << issue
    end
    
    assert_not_includes issues_found, @issue_16, "Issue 16 from project B should not be found"
  end

  test "issue resolved recently should not be selected" do
    Setting.plugin_redmine_autoclose = {
      'autoclose_active' => '1',
      'autoclose_projects' => 'project-a',
      'autoclose_resolved_status_ids' => [@status_resolved.id.to_s],
      'autoclose_closed_status_id' => @status_closed.id.to_s,
      'autoclose_tracker_ids' => [@tracker_bug.id.to_s],
      'autoclose_interval' => '30'
    }
    
    @issue_12.journals.destroy_all
    add_journal(@issue_12, @status_resolved, 5.days.ago)
    
    config = RedmineAutoclose::Config.new
    issues_found = []
    
    RedmineAutoclose::Autoclose.enumerate_issues(config, false) do |issue, when_resolved|
      issues_found << issue
    end
    
    assert_not_includes issues_found, @issue_12, "Issue resolved less than 30 days ago should not be found"
  end

  private

  def add_journal(issue, status, created_on)
    journal = Journal.create!(
      journalized: issue,
      user: @user,
      created_on: created_on
    )
    journal.details << JournalDetail.new(
      property: 'attr',
      prop_key: 'status_id',
      old_value: issue.status_id,
      value: status.id
    )
  end
end
