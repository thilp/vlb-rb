(English version below)

# Français

**vlb-rb** est un bot IRC fait pour faciliter les conversations sur le canal #vikidia de Freenode.
Ce fichier décrit comment utiliser ce bot, du point de vue d'un visiteur de ce canal.

## Nom

Le nom « VikiLinkBot » est une sorte d'hommage à [WikiLinkBot][], qui tenait auparavant ce rôle.
Ce dépôt utilise généralement « vlb-rb » au lieu de « VikiLinkBot » parce que c'est plus court
et rappelle le fait que vlb-rb n'est qu'_une_ implémentation de VikiLinkBot (il en existe une autre,
obsolète, en Python).

## Wikiliens

La mission première de VikiLinkBot est de transformer les `[[wikiliens]]` (écrits dans la conversation)
en hyperliens cliquables, comme [MediaWiki][] le fait sur les wikis. vlb-rb y ajoute les fonctionnalités
suivantes :

* l'existence de la page visée par un wikilien est testée, à moins que le lien ne commence par un deux-points
  (comme dans `[[:lien]]`) ;
* comme #vikidia rassemble les contributeurs de plusieurs wikis, on peut faire des liens vers n'importe quel
  wiki (basé sur MediaWiki), par exemple `[[fr.wikipedia.org:Saumon]]` ; pour les plus communs, il existe
  des alias, comme `[[frwp:Saumon]]` et `[[wp:Saumon]]`.

Note : à la différence de **W**ikiLinkBot, vlb-rb ne s'occupe pas des `{{modèles}}`.

## Commandes

Les commandes sont des « phrases » spéciales que vlb-rb interprète spécialement.
Elles doivent toujours commencer en début de ligne, ou le robot n'y prêtera pas attention.
La plus simple est `!version`, ce à quoi le robot répond en affichant son nom et son numéro de version.

### Simples liens

* `!aide` (cette page)

vlb-rb répondra aux commandes suivantes en retournant l'URL correspondante pour fr.vikidia.org :
* `!alerte` (page d'alerte)
* `!ba` (bulletin des administrateurs)
* `!bp` (bulletin des patrouilleurs)
* `!bavardages`
* `!cabane`
* `!commons` (page d'accueil de Wikimedia Commons)
* `!da` (demandes aux administrateurs)
* `!db` (demandes aux bureaucrates)
* `!plagium` (détecteur de plagiat)
* `!savant`
* `!tickets` (page servant à rapporter les problèmes techniques)

### Récupération d'informations

* `!info [WIKI] REQUÊTE`
  Permet d'interroger l'API du wiki `WIKI` (par défaut, fr.vikidia.org). `REQUÊTE` peut être soit une suite
  de mots-clefs séparés par des `/`, soit un alias qui sera interprété par vlb-rb comme la suite de mots-clefs
  équivalente. Ces mots-clefs sont listés sur https://www.mediawiki.org/wiki/API:Siteinfo.

# English

vlb-rb is an IRC bot designed to simplify conversations on the #vikidia channel of Freenode.
This file gives some background about the bot and then describes how to use it from a channel-member
point of view.

## Name

The name "VikiLinkBot" is a tribute to [WikiLinkBot][], which accompanied us before.
In this repository, "vlb-rb" is used instead of "VikiLinkBot" because it is shorter
and emphasizes the fact that this is just _one_ version of VikiLinkBot (the Ruby one,
the other being the obsolete Python one).

## Wikilinks

The primary goal of VikiLinkBot is to **watch for wikilinks**, i.e. `[[words|like that]]`,
and **transform them** into real hyperlinks that users can click — as if [MediaWiki][] was there
to make wikilinks "just work". vlb-rb supports this behaviour, with the following improvements:

* The existence of the linked page is checked, unless the link is prefixed with a colon (as in `[[:link]]`).
* #vikidia being a multi-wiki channel, any MediaWiki instance may be specified (as in
  `[[en.wikipedia.org:Salmon]]`) with aliases for commonly targeted ones (as in `[[enwp:Salmon]]`).

Note: A major difference with **W**ikiLinkBot is that vlb-rb doesn't watch for `{{templates}}`.

[WikiLinkBot]: <https://tools.wmflabs.org/wikilinkbot>
[MediaWiki]: <https://www.mediawiki.org>
