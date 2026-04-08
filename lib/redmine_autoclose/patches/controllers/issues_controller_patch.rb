module RedmineAutoclose
  module Patches
    module Controllers    
      module IssuesControllerPatch
        extend ActiveSupport::Concern

        included do
          before_action :handle_autoclose, only: [:update]
        end

        private
        
        def handle_autoclose
          return unless params[:issue] && params[:issue][:autoclose].present?

          autoclose_enabled = params[:issue][:autoclose] == '1'
          update_autoclose(autoclose_enabled)
        end

        def update_autoclose(autoclose_enabled)
          if @issue.autoclose_issue
            old_value = @issue.autoclose_issue.autoclose
            return if old_value == autoclose_enabled

            @issue.autoclose_issue.update(autoclose: autoclose_enabled)
            add_autoclose_journal_detail(old_value, autoclose_enabled)
          else
            @issue.create_autoclose_issue(autoclose: autoclose_enabled)
            add_autoclose_journal_detail(nil, autoclose_enabled)
          end
        end

        def add_autoclose_journal_detail(old_value, new_value)
          @issue.init_journal(User.current)
          @issue.current_journal.details.build(
            property: 'attr',
            prop_key: 'autoclose',
            old_value: old_value,
            value: new_value
          )
        end

      end
    end
  end
end

IssuesController.send(:include, RedmineAutoclose::Patches::Controllers::IssuesControllerPatch)
