class YandexImages
  def search(query)
    payload = {
      query: {
        searchType: "SEARCH_TYPE_RU",
        queryText: query
      },
      folderId: "b1grmu4ljlqafbhfnff2",
      responseFormat: "FORMAT_HTML",
      userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 YaBrowser/25.2.0.0 Safari/537.36"
    }

    res = HTTP
      .auth("Api-Key #{ENV.fetch('YANDEX_SEARCH_API_KEY')}")
      .post("https://searchapi.api.cloud.yandex.net/v2/image/search", {
        json: payload
      })

    xml = Base64.decode64(JSON.parse(res.body.to_s)["rawData"])
    doc = Nokogiri::XML(xml)
    image = doc.css("doc").first

    url = image.css("thumbnail-link").first.children.first.to_s

    uri = URI(url)
    uri.scheme = "https"
    params = Rack::Utils.parse_query(uri.query).merge({
      n: 33,
      w: 1200,
      h: 1200
    })
    uri.query = params.to_query
    new_url = uri.to_s

    {
      url: new_url,
      width: image.css("thumbnail-width").first.children.first.to_s,
      height: image.css("thumbnail-height").first.children.first.to_s,
    }
  end
end
