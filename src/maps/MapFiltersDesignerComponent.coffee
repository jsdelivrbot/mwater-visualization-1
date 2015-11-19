React = require 'react'
H = React.DOM
ExprComponent = require("mwater-expressions-ui").ExprComponent
ExprCleaner = require('mwater-expressions').ExprCleaner

# Designer for filters for a map
module.exports = class MapFiltersDesignerComponent extends React.Component
  @propTypes:
    schema: React.PropTypes.object.isRequired # Schema to use
    dataSource: React.PropTypes.object.isRequired # Data source to use
    layerFactory: React.PropTypes.object.isRequired # layer factory to use
    design: React.PropTypes.object.isRequired  # See Map Design.md
    onDesignChange: React.PropTypes.func.isRequired # Called with new design

  handleFilterChange: (table, expr) =>
    # Clean filter
    expr = new ExprCleaner(@props.schema).cleanExpr(expr, { table: table })

    update = {}
    update[table] = expr

    filters = _.extend({}, @props.design.filters, update)
    design = _.extend({}, @props.design, filters: filters)
    @props.onDesignChange(design)

  renderFilterableTable: (table) =>
    name = @props.schema.getTable(table).name

    H.div key: table, 
      H.h4 null, name
      React.createElement(ExprComponent, 
        schema: @props.schema
        dataSource: @props.dataSource
        onChange: @handleFilterChange.bind(null, table)
        type: "boolean"
        table: table
        value: @props.design.filters[table])

  render: ->
    # Get filterable tables
    filterableTables = []
    for layerView in @props.design.layerViews
      # Create layer
      layer = @props.layerFactory.createLayer(layerView.type, layerView.design)

      # Get filterable tables
      filterableTables = _.uniq(filterableTables.concat(layer.getFilterableTables()))

    H.div style: { margin: 5 }, 
      _.map(filterableTables, @renderFilterableTable)
