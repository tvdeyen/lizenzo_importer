# This model is the master routine for uploading products
# Requires Paperclip and CSV to upload the CSV file and read it nicely.

# Original Authors:: Josh McArthur, Chetan Mittal
# Author:: Thomas von Deyen
# License:: MIT

class LizenzoImport < ActiveRecord::Base
  has_attached_file :data_file, :path => ":rails_root/lib/etc/product_data/data-files/:basename.:extension"
  validates_attachment_presence :data_file
  
  require RUBY_VERSION == '1.8.7' ? 'fastercsv' : 'csv'
  require 'pp'
  require 'open-uri'
  
  ## Data Importing:
  # List Price maps to Master Price, Current MAP to Cost Price, Net 30 Cost unused
  # Width, height, Depth all map directly to object
  # Image main is created independtly, then each other image also created and associated with the product
  # Meta keywords and description are created on the product model
  
  def import_data!
    begin
      #Get products *before* import -
      @products_before_import = Product.all
      @skus_of_products_before_import = []
      @products_before_import.each do |product|
        @skus_of_products_before_import << product.sku
      end
      
      if RUBY_VERSION == '1.8.7'
        rows = FasterCSV.read(self.data_file.path, {:col_sep => ';', :quote_char => "'"})
      else
        rows = CSV.read(self.data_file.path, {:col_sep => ';', :quote_char => "'"})
      end
      
      if LIZENZO_IMPORTER_SETTINGS[:first_row_is_headings]
        col = get_column_mappings(rows[0])
      else
        col = LIZENZO_IMPORTER_SETTINGS[:column_mappings]
      end
      
      log("Importing products for #{self.data_file_file_name} began at #{Time.now}")
      rows[LIZENZO_IMPORTER_SETTINGS[:rows_to_skip]..-1].each do |row|
        product_information = {}
        
        #Automatically map 'mapped' fields to a collection of product information.
        #NOTE: This code will deal better with the auto-mapping function - i.e. if there
        #are named columns in the spreadsheet that correspond to product
        # and variant field names.
        col.each do |key, value|
          product_information[key] = row[value]
        end
        
        
        #Manually set available_on if it is not already set
        product_information[:available_on] = DateTime.now - 1.day if product_information[:available_on].nil?
        
        
        #Trim whitespace off the beginning and end of row fields
        row.each do |r|
          next unless r.is_a?(String)
          r.gsub!(/\A\s*/, '').chomp!
        end
        
        if LIZENZO_IMPORTER_SETTINGS[:create_variants]
          field = LIZENZO_IMPORTER_SETTINGS[:variant_comparator_field].to_s
          if p = Product.find(:first, :conditions => ["#{field} = ?", row[col[field.to_sym]]])
            p.update_attribute(:deleted_at, nil) if p.deleted_at #Un-delete product if it is there
            p.variants.each { |variant| variant.update_attribute(:deleted_at, nil) }
            create_variant_for(p, :with => product_information)
          else
            next unless create_product_using(product_information)
          end
        else
          next unless create_product_using(product_information)
        end
      end
      
      if LIZENZO_IMPORTER_SETTINGS[:destroy_original_products]
        @products_before_import.each { |p| p.destroy }
      end
      
      log("Importing products for #{self.data_file_file_name} completed at #{DateTime.now}")
      
    rescue Exception => exp
      log("An error occurred during import, please check file and try again. (#{exp.message})\n#{exp.backtrace.join('\n')}", :error)
      raise Exception(exp.message)
    end
    
    #All done!
    return [:notice, "Product data was successfully imported."]
  end
  
  
  private
  
  
  # create_variant_for
  # This method assumes that some form of checking has already been done to 
  # make sure that we do actually want to create a variant.
  # It performs a similar task to a product, but it also must pick up on
  # size/color options
  def create_variant_for(product, options = {:with => {}})
    return if options[:with].nil?
    variant = product.variants.new
    
    #Remap the options - oddly enough, Spree's product model has master_price and cost_price, while
    #variant has price and cost_price.
    options[:with][:price] = options[:with].delete(:master_price)
    
    #First, set the primitive fields on the object (prices, etc.)
    options[:with].each do |field, value|
      variant.send("#{field}=", value) if variant.respond_to?("#{field}=")
      applicable_option_type = OptionType.find(:first, :conditions => [
        "lower(presentation) = ? OR lower(name) = ?",
        field.to_s, field.to_s]
      )
      if applicable_option_type.is_a?(OptionType)
        product.option_types << applicable_option_type unless product.option_types.include?(applicable_option_type)
        variant.option_values << applicable_option_type.option_values.find(
          :all,
          :conditions => ["presentation = ? OR name = ?", value, value]
        )
      end
    end
    
    
    if variant.valid?
      variant.save
      
      #Associate our new variant with any new taxonomies
      LIZENZO_IMPORTER_SETTINGS[:taxonomy_fields].each do |field| 
        associate_product_with_taxon(variant.product, field.to_s, options[:with][field.to_sym])
      end
      
      #Finally, attach any images that have been specified
      LIZENZO_IMPORTER_SETTINGS[:image_fields].each do |field|
        find_and_attach_image_to(variant, options[:with][field.to_sym])
      end
      
      #Log a success message
      log("Variant of SKU #{variant.sku} successfully imported.\n")  
    else
      log("A variant could not be imported - here is the information we have:\n" +
          "#{pp options[:with]}, :error")
      return false
    end
  end
  
  
  # create_product_using
  # This method performs the meaty bit of the import - taking the parameters for the 
  # product we have gathered, and creating the product and related objects.
  # It also logs throughout the method to try and give some indication of process.
  def create_product_using(params_hash)
    
    if variant = Variant.find_by_sku(params_hash[:sku])
      # Updating if products already exists
      product = variant.product
      log("#{product.name} is already in the system. Updating.\n")
      
      params = params_hash.reject { |k, v| !LIZENZO_IMPORTER_SETTINGS[:fields_to_update].include? k }
      params.each do |field, value|
        if field == :cost_price
          value = BigDecimal.new((value.to_s.gsub(/1:/, '').to_f).to_s)
        end
        if RUBY_VERSION == '1.8.7'
          product.send("#{field}=", value) if product.respond_to?("#{field}=")
        else
          product.send("#{field}=", value.is_a?(String) ? value.force_encoding("UTF-8") : value) if product.respond_to?("#{field}=")
        end
      end
      
      if product.save
        log("#{product.name} successfully updated.\n")
      end
      
    else
      product = Product.new
      #The product is inclined to complain if we just dump all params 
      # into the product (including images and taxonomies). 
      # What this does is only assigns values to products if the product accepts that field.
      params_hash.each do |field, value|
        value = convert_value_to_price(value) if field == :master_price
        if RUBY_VERSION == '1.8.7'
          product.send("#{field}=", value) if product.respond_to?("#{field}=")
        else
          product.send("#{field}=", value.is_a?(String) ? value.force_encoding("UTF-8") : value) if product.respond_to?("#{field}=")
        end
      end
      
      # using backup name col if name is nil.
      if RUBY_VERSION == '1.8.7'
        product.name = params_hash[:backup_name] if product.name.nil?
      else
        product.name = params_hash[:backup_name].force_encoding("UTF-8") if product.name.nil?
      end
      
      #We can't continue without a valid product here
      unless product.valid?
        log("A product could not be imported - here is the information we have:\n" +
            "#{pp params_hash}, :error")
        return false
      end
      
      # Setting tax class
      product.tax_category_id = 1
      
      #Save the object before creating asssociated objects
      product.save
      
      #Associate our new product with any taxonomies that we need to worry about
      maincat = LIZENZO_IMPORTER_SETTINGS[:taxonomy_fields][0]
      subcat = LIZENZO_IMPORTER_SETTINGS[:taxonomy_fields][1]
      
      associate_product_with_taxon(product, params_hash[maincat.to_sym], params_hash[subcat.to_sym])
      
      #Finally, attach any images that have been specified
      LIZENZO_IMPORTER_SETTINGS[:image_fields].each do |field|
        find_and_attach_image_to(product, params_hash[field.to_sym])
      end
      
      if LIZENZO_IMPORTER_SETTINGS[:multi_domain_importing] && product.respond_to?(:stores)
        begin
          store = Store.find(
            :first, 
            :conditions => ["id = ? OR code = ?", 
              params_hash[LIZENZO_IMPORTER_SETTINGS[:store_field]],
              params_hash[LIZENZO_IMPORTER_SETTINGS[:store_field]]
            ]
          )
          
          product.stores << store
        rescue
          log("#{product.name} could not be associated with a store. Ensure that Spree's multi_domain extension is installed and that fields are mapped to the CSV correctly.")
        end
      end
      
      #Log a success message
      log("#{product.name} successfully imported.\n")
      
    end
    
    return true
  end
  
  # get_column_mappings
  # This method attempts to automatically map headings in the CSV files
  # with fields in the product and variant models.
  # If the headings of columns are going to be called something other than this,
  # or if the files will not have headings, then the manual initializer
  # mapping of columns must be used. 
  # Row is an array of headings for columns - SKU, Master Price, etc.)
  # @return a hash of symbol heading => column index pairs
  def get_column_mappings(row)
    mappings = {}
    row.each_with_index do |heading, index|
      mappings[heading.downcase.gsub(/\A\s*/, '').chomp.gsub(/\s/, '_').to_sym] = index
    end
    mappings
  end
  
  ### MISC HELPERS ####
  
  #Log a message to a file - logs in standard Rails format to logfile set up in the lizenzo_importer initializer
  #and console.
  #Message is string, severity symbol - either :info, :warn or :error
  
  def log(message, severity = :info)
    @rake_log ||= ActiveSupport::BufferedLogger.new(LIZENZO_IMPORTER_SETTINGS[:log_to])
    message = "[#{Time.now.to_s(:db)}] [#{severity.to_s.capitalize}] #{message}\n"
    @rake_log.send severity, message
    puts message
  end
  
  
  ### IMAGE HELPERS ###
  
  # find_and_attach_image_to
  # This method attaches images to products. The images may come 
  # from a local source (i.e. on disk), or they may be online (HTTP/HTTPS).
  def find_and_attach_image_to(product_or_variant, filename)
    return if filename.blank?
    
    # Fetching the image from life-trends server
    image_url = 'http://www.life-trends24.de/images/product_images/popup_images/' + filename
    file = fetch_remote_image(image_url)
    
    #An image has an attachment (the image file) and some object which 'views' it
    product_image = Image.new({
      :attachment => file,
      :viewable => product_or_variant,
      :position => product_or_variant.images.length
    })
    
    product_or_variant.images << product_image if product_image.save
  end
  
  # This method is used when we have a set location on disk for
  # images, and the file is accessible to the script.
  # It is basically just a wrapper around basic File IO methods.
  def fetch_local_image(filename)
    filename = LIZENZO_IMPORTER_SETTINGS[:product_image_path] + filename
    unless File.exists?(filename) && File.readable?(filename)
      log("Image #{filename} was not found on the server, so this image was not imported.", :warn)
      return nil
    else
      return File.open(filename, 'rb')
    end
  end
  
  #This method can be used when the filename matches the format of a URL.
  # It uses open-uri to fetch the file, returning a Tempfile object if it
  # is successful.
  # If it fails, it in the first instance logs the HTTP error (404, 500 etc)
  # If it fails altogether, it logs it and exits the method.
  def fetch_remote_image(filename)
    begin
      extname = File.extname(filename)
      basename = File.basename(filename, extname)
      file = Tempfile.new([basename, extname])
      file.binmode
      open(URI.parse(filename)) do |data|
        file.write data.read
      end
      file.rewind
      return file
    rescue OpenURI::HTTPError => error
      log("Image #{filename} retrival returned #{error.message}, so this image was not imported")
    rescue
      log("Image #{filename} could not be downloaded, so was not imported.")
    end
  end
  
  ### TAXON HELPERS ###
  
  # associate_product_with_taxon
  # This method accepts three formats of taxon hierarchy strings which will
  # associate the given products with taxons:
  # 1. A string on it's own will will just find or create the taxon and 
  # add the product to it. e.g. taxonomy = "Category", taxon_hierarchy = "Tools" will
  # add the product to the 'Tools' category.
  # 2. A item > item > item structured string will read this like a tree - allowing
  # a particular taxon to be picked out 
  # 3. An item > item & item > item will work as above, but will associate multiple
  # taxons with that product. This form should also work with format 1. 
  def associate_product_with_taxon(product, taxonomy, taxon_hierarchy)
    return if product.nil? || taxonomy.nil?
    # Using find_or_create_by_name is more elegant, but our magical params code automatically downcases 
    # the taxonomy name, so unless we are using MySQL, this isn't going to work.
    taxonomy_name = RUBY_VERSION == '1.8.7' ? taxonomy : taxonomy.force_encoding("UTF-8")
    
    taxonomy = Taxonomy.find(:first, :conditions => ["lower(name) = ?", taxonomy])
    taxonomy = Taxonomy.create(:name => taxonomy_name.capitalize) if taxonomy.nil? && LIZENZO_IMPORTER_SETTINGS[:create_missing_taxonomies]
    
    if taxon_hierarchy.blank?
      
      taxon_root = taxonomy.root
      taxon = taxon_root.children.find_or_create_by_name_and_taxonomy_id(taxonomy.name, taxonomy.id)
      product.taxons << taxon unless product.taxons.include?(taxon)
      
    else
      
      taxon_hierarchy.split(/\s*\&\s*/).each do |hierarchy|
        hierarchy = hierarchy.split(/\s*>\s*/)
        last_taxon = taxonomy.root
        hierarchy.each do |taxon|
          last_taxon = last_taxon.children.find_or_create_by_name_and_taxonomy_id(RUBY_VERSION == '1.8.7' ? taxon : taxon.force_encoding("UTF-8"), taxonomy.id)
        end
        
        #Spree only needs to know the most detailed taxonomy item
        product.taxons << last_taxon unless product.taxons.include?(last_taxon)
      end
      
    end
  end
  ### END TAXON HELPERS ###
  
  def convert_value_to_price(value)
    BigDecimal.new((value.to_s.to_f/10000).to_s)
  end
  
end
