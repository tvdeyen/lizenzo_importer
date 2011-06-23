# This file is the thing you have to config to match your application

LIZENZO_IMPORTER_SETTINGS = {
  :column_mappings => { #Change these for manual mapping of product fields to the CSV file
    :sku => 1,
    :count_on_hand => 2,
    :name => 43,
    :backup_name => 54,
    :master_price => 8,
    :cost_price => 14,
    :image_main => 42,
    :image_2 => 37,
    :image_3 => 38,
    :image_4 => 39,
    :image_5 => 40,
    :description => 44,
    :category => 60,
    :subcategory => 61,
    :meta_description => 46,
    :meta_keywords => 48
  },
  :create_missing_taxonomies => true,
  :taxonomy_fields => [:category, :subcategory], #Fields that should automatically be parsed for taxons to associate
  :image_fields => [:image_main, :image_2, :image_3, :image_4, :image_5], #Image fields that should be parsed for image locations
  :product_image_path => "#{Rails.root}/lib/etc/product_data/product-images/", #The location of images on disk
  :rows_to_skip => 1, #If your CSV file will have headers, this field changes how many rows the reader will skip
  :log_to => File.join(Rails.root, '/log/', "lizenzo_importer_#{Rails.env}.log"), #Where to log to
  :destroy_original_products => false, #Delete the products originally in the database after the import?
  :first_row_is_headings => false, #Reads column names from first row if set to true.
  :create_variants => false, #Compares products and creates a variant if that product already exists.
  :variant_comparator_field => :permalink, #Which product field to detect duplicates on
  :multi_domain_importing => false, #If Spree's multi_domain extension is installed, associates products with store
  :store_field => :store_code, #Which field of the column mappings contains either the store id or store code?
  :fields_to_update => [:cost_price, :count_on_hand] #An array of symbols with cols that should be updated on existing products
}
