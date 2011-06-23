class LizenzoImporterHooks < Spree::ThemeSupport::HookListener
  # custom hooks go here
  
  Deface::Override.new(
    :virtual_path => "layouts/admin",
    :name => 'lizenzo_importer_tab',
    :insert_bottom => "[data-hook='admin_tabs']",
    :text => "<%= tab(:lizenzo_imports) %>"
  )
  
end
