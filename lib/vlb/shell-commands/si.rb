module VikiLinkBot
  class Shell

    def si(m, _)
      wiki = WikiFactory.instance.get('fr.vikidia.org')
      answer = wiki.api action: 'query', prop: 'categoryinfo', indexpageids: 1,
                        titles: 'Catégorie:Suppression_immédiate'
      category_size = answer['query']['pages'][answer['query']['pageids'][0]]['categoryinfo']['size']
      url = wiki.article_url('Catégorie:Suppression_immédiate')
      m.reply "À supprimer : #{category_size} - #{url}"
    end

  end
end