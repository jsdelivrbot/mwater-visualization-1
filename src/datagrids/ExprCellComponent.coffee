_ = require 'lodash'
React = require 'react'
H = React.DOM
R = React.createElement
moment = require 'moment'

ExprUtils = require("mwater-expressions").ExprUtils

Cell = require('fixed-data-table').Cell

# Cell that displays an expression column cell
module.exports = class ExprCellComponent extends React.Component
  @propTypes:
    schema: React.PropTypes.object.isRequired     # schema to use
    dataSource: React.PropTypes.object.isRequired # dataSource to use

    exprType: React.PropTypes.string.isRequired

    width: React.PropTypes.number.isRequired
    height: React.PropTypes.number.isRequired

    value: React.PropTypes.any
    expr: React.PropTypes.object.isRequired

    onClick: React.PropTypes.func

  handleClick: =>
    @setState(editing: true)

  renderImage: (id) ->
    url = @props.dataSource.getImageUrl(id)
    return H.a(href: url, key: id, target: "_blank", style: { paddingLeft: 5, paddingRight: 5 }, "Image")

  render: ->
    exprUtils = new ExprUtils(@props.schema)
    value = @props.value

    if not value?
      node = null
    else
      # Parse if should be JSON
      if @props.exprType in ['image', 'imagelist', 'geometry', 'text[]'] and _.isString(value)
        value = JSON.parse(value)

      # Convert to node based on type
      switch @props.exprType
        when "text", "number"
          node = value
        when "boolean", "enum", "enumset", "text[]"
          node = exprUtils.stringifyExprLiteral(@props.expr, value)
        when "date"
          node = moment(value, "YYYY-MM-DD").format("ll")
        when "datetime"
          node = moment(value, moment.ISO_8601).format("lll")
        when "image"
          node = @renderImage(value.id)
        when "imagelist"
          node = _.map(value, (v) => @renderImage(v.id))
        when "geometry"
          node = "#{value.coordinates[1].toFixed(6)} #{value.coordinates[0].toFixed(6)}" 
        else
          node = "" + value

    return R Cell, 
      width: @props.width
      height: @props.height
      onClick: @props.onClick
      style: { whiteSpace: "nowrap" }, 
        node