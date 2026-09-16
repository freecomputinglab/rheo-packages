#import "../_template.typ": template
#show: template
#import "@rheo/sitemap:0.1.0": blogfeed, date-cell, post-date

= Posts

#blogfeed(meta: e => date-cell[#post-date(e).display()])
