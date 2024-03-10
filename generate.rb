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
  inclusion_page_title_patterns = config.dig("input", "inclusion_page_title_patterns")
  exclusion_page_title_patterns = config.dig("input", "exclusion_page_title_patterns")

  feed_title = config.dig("output", "feed_title")
  feed_description = config.dig("output", "feed_description")
  feed_author = config.dig("output", "feed_author")
  file_name = config.dig("output", "file_name")

  original_feed = RSS::Parser.parse(HTTP.get("https://scrapbox.io/api/feed/#{project}").body.to_s)
  original_title = original_feed.channel.title
  original_description = original_feed.channel.description

  xml_published_url = "https://junebako.github.io/sff/#{project}/#{file_name}.xml"

  puts "Processing: #{project} - #{feed_title}"

  pages = original_feed.items.filter do
    page_title = _1.title.sub(" - #{original_title}", "")

    inclusion_page_title_patterns.any? { |pattern| page_title.match(Regexp.compile(pattern)) } &&
    !exclusion_page_title_patterns.any? { |pattern| page_title.match(Regexp.compile(pattern)) }
  end

  xml = Builder::XmlMarkup.new(indent: 2)

  xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
  xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
    xml.id "https://scrapbox.io/#{project}/"
    xml.title feed_title
    xml.subtitle feed_description
    xml.author do |author|
      author.name feed_author
    end
    xml.link href: "https://scrapbox.io/#{project}/"
    xml.link href: xml_published_url, rel: "self"
    xml.updated pages.size > 0 ? pages.sort_by(&:pubDate).last.pubDate.to_datetime.rfc3339 : Time.now.to_datetime.rfc3339

    pages.sort_by(&:pubDate).reverse.each do |item|
      page_title = item.title.sub(" - #{original_title}", "")
      puts "  - #{page_title}"

      xml.entry do
        xml.title page_title
        xml.link href: item.link
        xml.id item.link
        xml.updated item.pubDate.to_datetime.rfc3339
        xml.content type: "html" do
          xml.cdata! item.description.to_s
        end
      end
    end
  end

  directory_path = "public/#{project}"
  Dir.mkdir(directory_path) unless File.exist?(directory_path)
  file_path = "public/#{project}/#{file_name}.xml"
  File.write(file_path, xml.target!)

  puts "Generated: #{file_path}"
  puts "Will be published at: #{xml_published_url}"
  puts
end
