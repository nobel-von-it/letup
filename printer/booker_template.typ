#let horizontalrule = [#v(0.5em)#align(center, line(length: 30%, stroke: 0.5pt))#v(0.5em)]

#let book(
  title: [],
  author: [],
  body,
) = {
  set page(
    paper: "a5",
    margin: (inside: 12mm, outside: 6mm, top: 6mm, bottom: 6mm),
    numbering: "1",
  )
  
  set text(font: ("Linux Libertine", "Liberation Serif", "DejaVu Serif", "Noto Serif"), size: 10.5pt, lang: "ru")
  set par(justify: true, leading: 0.65em, first-line-indent: 1.5em)

  show outline.entry.where(level: 1): it => {
    v(12pt, weak: true)
    strong(it)
  }
  
  set outline(indent: auto)
  set outline.entry(fill: repeat([. ]))
  
  show heading: it => {
    if it.level == 1 {
      pagebreak(weak: true)
      v(4em)
      align(center)[
        #text(size: 1.6em, weight: "bold", it.body)
      ]
      v(2.5em, weak: true)
    } else if it.level == 2 {
      v(2.5em, weak: true)
      align(center)[
        #text(size: 1.3em, weight: "bold", it.body)
      ]
      v(1.5em, weak: true)
    } else {
      v(1.5em, weak: true)
      text(size: 1.1em, weight: "bold", it.body)
      v(1em, weak: true)
    }
    par(text(size: 0pt, ""))
  }

  if title != [] {
    align(center)[
      #v(4em)
      #block(text(weight: 700, 2em, title))
      #v(2em, weak: true)
      #block(text(1.4em, author))
    ]
    pagebreak(weak: true)
  }

  outline(title: [Содержание], depth: 2)
  pagebreak(weak: true)

  body
}

#show: book.with(
  title: [$title$],
  author: [$for(author)$$author$$sep$, $endfor$]
)

$body$
