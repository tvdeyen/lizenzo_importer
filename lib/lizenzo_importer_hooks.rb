class LizenzoImporterHooks < Spree::ThemeSupport::HookListener
  # custom hooks go here
  insert_after :admin_tabs do
   %(<%= tab(:lizenzo_import_index) %>)
  end
end
