require "liquid"
require "json"

STDOUT.sync = true

# basic file system to allow hyphens and full paths
class StubFileSystem
  def initialize(root)
    @root = root
  end

  # Liquid 5.x might pass (path) or (path, context) depending on internal method calls
  # We accept *args to be safe
  def read_template_file(template_path, *args)
    # Handle standard Shopify render: {% render 'name' %} -> looking for snippets/name.liquid
    full_path = File.join(@root, "#{template_path}.liquid")
    
    unless File.exist?(full_path)
      # Try without extension
      full_path = File.join(@root, template_path)
    end

    unless File.exist?(full_path)
      raise Liquid::FileSystemError, "No such template '#{template_path}' at #{full_path}"
    end
    
    File.read(full_path)
  end
end

# Register the custom file system
Liquid::Template.file_system = StubFileSystem.new("snippets")

# Mock Shopify Filters
module ShopifyFilters
  def asset_url(input, *args)
    # puts "DEBUG: asset_url called with #{input.inspect}, args: #{args.inspect}"
    "/assets/#{input}"
  end

  def t(input, *args)
    # puts "DEBUG: t called with #{input.inspect}, args: #{args.inspect}"
    input.split(".").last.capitalize
  end

  def link_to(input, *args)
    # puts "DEBUG: link_to called with #{input.inspect}, args: #{args.inspect}"
    url = args.first
    "<a href='#{url}'>#{input}</a>"
  end

  def url_encode(input, *args)
    input 
  end
  
  def escape(input, *args)
    input
  end

  def inline_asset_content(input, *args)
    # puts "DEBUG: inline_asset_content called with #{input.inspect}, args: #{args.inspect}"
    "<svg>mock_icon_#{input}</svg>"
  end

  def find_index(input, *args)
    # puts "DEBUG: find_index called with #{input.inspect}, args: #{args.inspect}"
    nil
  end

  def image_url(input, *args)
    # puts "DEBUG: image_url called with #{input.inspect}, args: #{args.inspect}"
    "mock_image_url.jpg"
  end

  def image_tag(input, *args)
    # puts "DEBUG: image_tag called with #{input.inspect},, args: #{args.inspect}"
    options = args.first || {}
    "<img src='#{input}' alt='#{options['alt']}' />"
  end
  
  # Add other filters as they are discovered
end

Liquid::Template.register_filter(ShopifyFilters)

# Mock Shopify Tags
class SchemaTag < Liquid::Block
  def render(context)
    "" # Render nothing
  end
end

class StylesheetTag < Liquid::Block
  def render(context)
    "<style>#{super}</style>"
  end
end

class JavascriptTag < Liquid::Block
  def render(context)
    "<script>#{super}</script>"
  end
end

class ContentForTag < Liquid::Tag
  def render(context)
    "<!-- content_for #{@markup} -->"
  end
end

class DocTag < Liquid::Block
    def render(context)
        "" # Render nothing, it's documentation
    end
end

Liquid::Template.register_tag("schema", SchemaTag)
Liquid::Template.register_tag("stylesheet", StylesheetTag)
Liquid::Template.register_tag("javascript", JavascriptTag)
Liquid::Template.register_tag("content_for", ContentForTag)
Liquid::Template.register_tag("doc", DocTag)


# Load the snippet we want to test
# We use a dummy template that renders the target snippet
template_content = "{% render 'facets-sidebar', results: collection, section: section %}"
template = Liquid::Template.parse(template_content)


# Construct Mock Data
# Mimic existing data structures from Shopify
# Collection / Search Results
mock_collection = {
  "url" => "/collections/all",
  "products_count" => 12,
  "sort_by" => "price-ascending",
  "default_sort_by" => "title-ascending",
  "filters" => [
    {
      "label" => "Availability",
      "type" => "list",
      "active_values" => [],
      "presentation" => "text", # default
      "param_name" => "filter.v.availability",
      "values" => [
        { "label" => "In stock", "count" => 10, "active" => false, "value" => "1", "param_name" => "filter.v.availability", "swatch" => nil },
        { "label" => "Out of stock", "count" => 2, "active" => false, "value" => "0", "param_name" => "filter.v.availability", "swatch" => nil }
      ]
    }, 
    {
      "label" => "Price",
      "type" => "price_range",
      "param_name" => "filter.v.price",
      "min_value" => { "value" => 0 },
      "max_value" => { "value" => 100 },
      "range_max" => 100
    }
  ]
}

# Section Object
mock_section = {
  "id" => "sidebar-filter",
  "settings" => {
    "color_scheme" => "scheme-1"
  }
}

data = {
  "collection" => mock_collection,
  "section" => mock_section
}

# Render
begin
  # Render with strict variables off to avoid crashing on missing data
  output = template.render(data, { strict_variables: false, strict_filters: false })
  
  # Wrap in a basic HTML structure for viewing
  html_wrapper = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Liquid Local Render</title>
      <style>
        /* Basic styles to make it look decent */
        body { font-family: sans-serif; padding: 20px; }
        .facets-sidebar { border: 1px solid #ccc; padding: 10px; }
      </style>
    </head>
    <body>
      <h1>Rendered Output</h1>
      <hr>
      #{output}
      <hr>
      <h2>Debug Info</h2>
      <p>Errors: #{template.errors}</p>
    </body>
    </html>
  HTML

  File.open("output.html", "w") { |file| file.write(html_wrapper) }
  puts "Successfully rendered to output.html"
  
  if template.errors.any?
    puts "Template has errors:"
    template.errors.each do |e| 
      puts "Error: #{e.message}"
      puts e.backtrace.join("\n") if e.respond_to?(:backtrace) && e.backtrace
      puts "---"
    end
  end

rescue StandardError => e
  puts "Rendering Failed: #{e.message}"
  puts e.backtrace
end
