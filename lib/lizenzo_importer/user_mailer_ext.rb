module LizenzoImporter
  module UserMailerExt
    def self.included(base)
      base.class_eval do
        def lizenzo_import_results(user, error = nil)
          @user = user
          @error = error
          attachments["lizenzo_importer.log"] = File.read(LIZENZO_IMPORTER_SETTINGS[:log_to]) if @error.nil?
          mail(:to => @user.email, :subject => "Spree: Lizenzo Importer #{error.nil? ? "Success" : "Failure"}")
        end
      end
    end
  end
end
