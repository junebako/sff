require "bundler/inline"
require "rss"
require "yaml"

gemfile do
  source "https://rubygems.org"
  gem "http"
  gem "builder"
end

configs = YAML.load_file("config.yml")

configs.each do |config|
  project = config.dig("input", "project")
  inclusion_page_title_pattern = config.dig("input", "inclusion_page_title_pattern")
  exclusion_page_title_pattern = config.dig("input", "exclusion_page_title_pattern")

  feed_title = config.dig("output", "feed_title")
  feed_author = config.dig("output", "feed_author")
  file_name = config.dig("output", "file_name")

  original_feed = RSS::Parser.parse(HTTP.get("https://scrapbox.io/api/feed/#{project}").body.to_s)
  original_title = original_feed.channel.title
  original_description = original_feed.channel.description

  puts "Processing: #{project} - #{feed_title}"

  pages = original_feed.items.filter do
    page_title = _1.title.sub(" - #{original_title}", "")

    page_title.match(Regexp.compile(inclusion_page_title_pattern)) &&
    !page_title.match(Regexp.compile(exclusion_page_title_pattern))
  end

  xml = Builder::XmlMarkup.new(indent: 2)

  xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
  xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
    xml.id "https://scrapbox.io/#{project}/"
    xml.title feed_title
    xml.author do |author|
      author.name feed_author
    end
    xml.link href: "https://scrapbox.io/#{project}/"
    xml.link href: "https://juneboku-sandbox.github.io/scrapbox-filtered-feed/#{project}/#{file_name}.xml", rel: "self"
    xml.updated pages.sort_by(&:pubDate).last.pubDate.to_datetime.rfc3339

    pages.sort_by(&:pubDate).reverse.each do |item|
      page_title = item.title.sub(" - #{original_title}", "")
      puts "  - #{page_title}"

      xml.entry do
        xml.title page_title
        xml.link href: item.link
        xml.id item.link
        xml.updated item.pubDate.to_datetime.rfc3339
        xml.content type: "html" do
          xml.cdata! item.description
        end
      end
    end
  end

  directory_path = "public/#{project}"
  Dir.mkdir(directory_path) unless File.exist?(directory_path)
  file_path = "public/#{project}/#{file_name}.xml"
  File.write(file_path, xml.target!)

  puts "Generated: #{file_path}"
  puts
end
