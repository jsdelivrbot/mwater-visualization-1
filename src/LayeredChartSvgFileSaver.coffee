LayeredChartCompiler = require './LayeredChartCompiler'
saveAs = require 'filesaver.js'

# Get the css rules corresponding to .c3 directly out of the document object
getC3Css = () =>
  css = []
  for sheet in document.styleSheets
    rules = sheet.cssRules or sheet.rules
    for rule in rules
      if rule.cssText and rule.cssText.startsWith(".c3")
        css.push(rule.cssText)
  return css.join('\n')

# Get the svg XML text straight from the DOM node, adding the css styling to it as a <style> element
getC3String = (c3Node) =>
  # Log SVG with stylesheet info
  # First get the svg DOM node and make a copy as an XML doc
  svgStr = c3Node.outerHTML
  xml = $.parseXML(svgStr)
  svgNode = xml.documentElement
  # Denote it as svg
  svgNode.setAttribute("xmlns", "http://www.w3.org/2000/svg")
  svgNode.setAttribute("xmlns:xlink", "http://www.w3.org/1999/xlink")
  # Add a style element with the .c3 css rules for this page
  styleNode = xml.createElement("style")
  styleNode.setAttribute("type", "text/css")
  css = getC3Css()
  cdata = xml.createCDATASection(css)
  styleNode.appendChild(cdata)
  svgNode.insertBefore(styleNode, svgNode.firstChild)
  # Serialize
  svgFinalStr = new XMLSerializer().serializeToString(xml)
  return svgFinalStr

# Creates the svg string and saves that to file
saveSvgToFile = (containerDiv, title) ->
  svgFinalStr = getC3String(containerDiv.firstChild)
  document.body.removeChild(containerDiv)
  blob = new Blob([svgFinalStr], {type: "image/svg+xml"})
  saveAs(blob, (title or "unnamed-chart") + ".svg")

# Saves svg files from layered charts
# design: design of the chart
# data: results from queries
# schema: the chart's schema
module.exports = save: (design, data, schema) ->
  compiler = new LayeredChartCompiler(schema: schema)
  props =
    design: design
    data: data
    width: 400
    height: 400
  chartOptions = compiler.createChartOptions(props)
  containerDiv = document.createElement("div")
  document.body.appendChild(containerDiv) # Otherwise d3 getBBox doesn't work, odd title placement
  chartOptions.bindto = containerDiv
  title = design.titleText
  chartOptions.onrendered = => _.defer(-> saveSvgToFile(containerDiv, title))
  c3.generate(chartOptions)