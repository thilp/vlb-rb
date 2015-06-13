vlb-rb is an IRC bot designed to simplify conversations on the #vikidia channel of Freenode. This file gives some background about the bot and then describes how to use it from a channel-member point of view.

The name "VikiLinkBot" is a tribute to [WikiLinkBot](https://tools.wmflabs.org/wikilinkbot), which accompanied us before. In this repository, "vlb-rb" is used instead of "VikiLinkBot" because it is shorter and emphasizes the fact that this is only _one_ version of VikiLinkBot (the Ruby one, the other being the obsolete Python one).

The primary goal of VikiLinkBot is to **watch for wikilinks**, i.e. `[[words|like that]]`, and **transform them** into real hyperlinks that users can click — as if text sent to the chan was "preprocessed" by [MediaWiki](https://www.mediawiki.org). vlb-rb supports this behaviour, with the following improvements:

* The existence of the linked page is checked, unless the link is prefixed with a colon (as in `[[:link]]`).
* #vikidia being a multi-wiki channel, any MediaWiki instance may be specified (as in `[[en.wikipedia.org:Salmon]]`) with aliases for commonly targeted ones (as in `[[enwp:Salmon]]`).

Note: A major difference with **W**ikiLinkBot is that **V**ikiLinkBot doesn't watch for `{{templates}}`.
