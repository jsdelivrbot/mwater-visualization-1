React = require 'react'
H = React.DOM

# Component that is blue to show that it is a link and responds to clicks
module.exports = class EditableLinkComponent extends React.Component
  @propTypes:
    onClick: React.PropTypes.func # Called on click
    onRemove: React.PropTypes.func # Adds an x if specified 
    dropdownItems: React.PropTypes.array # Array of id, name or value, label to display as dropdown
    onDropdownItemClicked: React.PropTypes.func # Called with id/value of dropdown item

  renderRemove: ->
    if @props.onRemove
      return H.span className: "editable-link-remove", onClick: @props.onRemove,
        H.span(className: "glyphicon glyphicon-remove")

  renderDropdownItem: (item) =>
    id = item.id or item.value
    name = item.name or item.label

    return H.li key: id,
      H.a(key: id, onClick: @props.onDropdownItemClicked.bind(null, id), name)

  render: ->
    elem = H.div className: "editable-link", "data-toggle": "dropdown", 
      H.div style: { display: "inline-block" }, onClick: @props.onClick,
        @props.children
      @renderRemove()

    # If dropdown
    if @props.dropdownItems
      return H.div className: "dropdown", style: { display: "inline-block" },
        elem
        H.ul className: "dropdown-menu",
          _.map @props.dropdownItems, @renderDropdownItem
    else
      return elem
