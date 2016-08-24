# Carousel component for images. Starts with cover photo
React = require 'react'
H = React.DOM
R = React.createElement

# Bootstrap carousel for an image list
module.exports = class ImagelistCarouselComponent extends React.Component
  @propTypes:
    imagelist: React.PropTypes.array  # Array of { id, cover: true/false }
    widgetDataSource: React.PropTypes.object.isRequired
    height: React.PropTypes.number

  constructor: ->
    super
    @state = {
      activeImage: _.findIndex(@props.imagelist, { cover: true })
    }
    if @state.activeImage < 0
      @state.activeImage = 0

  handleLeft: =>
    if @props.imagelist and @props.imagelist.length > 0
      activeImage = (@state.activeImage - 1 + @props.imagelist.length) % @props.imagelist.length
      @setState(activeImage: activeImage)

  handleRight: =>
    if @props.imagelist and @props.imagelist.length > 0
      activeImage = (@state.activeImage + 1 + @props.imagelist.length) % @props.imagelist.length
      @setState(activeImage: activeImage)

  renderImage: (img, i) ->
    H.div className: "item #{if i == @state.activeImage then "active" else ""}", style: {height: @props.height},
      H.img style: { margin: '0 auto', height: @props.height }, src: @props.widgetDataSource.getImageUrl(img.id, 640)

  renderImages: ->
    counter = 0
    for row, i in @props.imagelist
      imageObj = row.value

      # Ignore nulls (https://github.com/mWater/mwater-server/issues/202)
      if not imageObj
        continue

      if _.isString(imageObj)
        imageObj = JSON.parse(imageObj)

      if _.isArray(imageObj)
        for image in imageObj
          @renderImage(image, counter++)
      else
        @renderImage(imageObj, counter++)

  render: ->
    H.div className: "image-carousel-component carousel slide", style: {height: @props.height, overflow: 'hidden'},
      if @props.imagelist.length < 10
        H.ol className: "carousel-indicators",
          _.map @props.imagelist, (img, i) =>
            H.li className: if i == @state.activeImage then "active"

      # Wrapper for slides
      H.div className: "carousel-inner",
        @renderImages()

      H.a className: "left carousel-control",
        H.span className: "glyphicon glyphicon-chevron-left", onClick: @handleLeft
      H.a className: "right carousel-control",
        H.span className: "glyphicon glyphicon-chevron-right", onClick: @handleRight