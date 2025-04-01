module Jekyll
  class CategoryPageGenerator < Generator
    safe true

    def generate(site)
      categories = site.posts.docs.flat_map { |post| post.data['categories'] }.uniq
      categories.each do |category|
        site.pages << CategoryPage.new(site, category)
      end
    end
  end

  class CategoryPage < Page
    def initialize(site, category)
      @site = site
      @base = site.source
      @dir  = "categories/#{category.downcase.gsub(' ', '-')}/"
      @name = "index.html"

      self.process(@name)
      self.read_yaml(File.join(@base, "_layouts"), "category.html")
      self.data['category'] = category
      self.data['title'] = "Category: #{category.capitalize}"
    end
  end
end
