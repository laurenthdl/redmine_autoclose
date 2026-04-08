module RedmineAutoclose
  module Patches
    module IssuePatch
      def self.included(base)
        base.class_eval do
          has_one :autoclose_issue, dependent: :destroy

          accepts_nested_attributes_for :autoclose_issue, allow_destroy: true, update_only: true
        end
      end


       def autoclose
         autoclose_issue&.autoclose || true
       end

      
      def autoclose_enabled
        settings = Setting.plugin_redmine_autoclose
        settings[:autoclose_tracker_ids]&.include?(self.tracker_id.to_s)
      end
    end
  end
end


Issue.send(:include, RedmineAutoclose::Patches::IssuePatch)
