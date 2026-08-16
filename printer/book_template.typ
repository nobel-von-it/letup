#let horizontalrule = [#v(0.5em)#align(center, line(length: 30%, stroke: 0.5pt))#v(0.5em)]

#let book(
  title: "Неизвестно",
  author: "Неизвестно",
  paper-size: "a5", // Классический книжный формат
  body
) = {
  // Настройки метаданных
  set document(title: title, author: author)
  
  // Настройки страницы (асимметричные поля для сшивки!)
  // Внутреннее поле (inside) всегда больше, чтобы текст не уходил в корешок
  set page(
    paper: paper-size,
    margin: (inside: 12mm, outside: 8mm, top: 8mm, bottom: 8mm),
    numbering: "1",
  )

  // Настройки шрифта (лучше использовать шрифты с засечками для печати)
  set text(font: ("Linux Libertine", "Liberation Serif", "DejaVu Serif", "Noto Serif"), size: 10.5pt, lang: "ru")
  
  // Настройки абзаца: выравнивание по ширине, отступ первой строки, висячие строки
  set par(
    justify: true, 
    leading: 0.65em, 
    first-line-indent: 1.5em
  )

  // Настройки заголовков (чтобы они не слипались с текстом)
  show heading: set block(above: 1.5em, below: 1em)
  show heading.where(level: 1): it => {
    pagebreak(weak: true) // Каждая глава с новой страницы
    v(2em)
    text(1.5em, weight: "bold", it.body)
    v(1.5em)
  }

  // Титульный лист
  align(center + horizon)[
    #text(2.5em, weight: "bold", title) \
    #v(1em)
    #text(1.5em, author)
  ]
  pagebreak()

  // Сам текст книги
  body
}