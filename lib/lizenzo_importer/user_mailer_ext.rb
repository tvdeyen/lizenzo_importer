module LizenzoImporter
  module UserMailerExt
    def self.included(base)
      base.class_eval do
        def lizenzo_import_results(user, error_message = nil)
          @user = user
          @error_message = error_message
          attachments["lizenzo_importer.log"] = File.read(LIZENZO_IMPORTER_SETTINGS[:log_to]) if @error_message.nil?
          mail(:to => @user.email, :subject => "Spree: Lizenzo Importer #{error_message.nil? ? "Success" : "Failure"}")
        end
      end
    end
  end
end
