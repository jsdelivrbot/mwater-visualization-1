var ExpressionBuilder, ExpressionCompiler, LayeredChartCompiler;

ExpressionCompiler = require('./ExpressionCompiler');

ExpressionBuilder = require('./ExpressionBuilder');

module.exports = LayeredChartCompiler = (function() {
  function LayeredChartCompiler(options) {
    this.schema = options.schema;
    this.exprBuilder = new ExpressionBuilder(this.schema);
  }

  LayeredChartCompiler.prototype.getLayerType = function(design, layerIndex) {
    return design.layers[layerIndex].type || design.type;
  };

  LayeredChartCompiler.prototype.doesLayerNeedGrouping = function(design, layerIndex) {
    return this.getLayerType(design, layerIndex) !== "scatter";
  };

  LayeredChartCompiler.prototype.isExprCategorical = function(expr) {
    var ref;
    return (ref = this.exprBuilder.getExprType(expr)) === 'text' || ref === 'enum' || ref === 'boolean';
  };

  LayeredChartCompiler.prototype.compileExpr = function(expr) {
    var exprCompiler;
    exprCompiler = new ExpressionCompiler(this.schema);
    return exprCompiler.compileExpr({
      expr: expr,
      tableAlias: "main"
    });
  };

  LayeredChartCompiler.prototype.getQueries = function(design, extraFilters) {
    var colorExpr, filter, i, j, layer, layerIndex, len, queries, query, ref, relevantFilters, whereClauses, xExpr, yExpr;
    queries = {};
    for (layerIndex = i = 0, ref = design.layers.length; 0 <= ref ? i < ref : i > ref; layerIndex = 0 <= ref ? ++i : --i) {
      layer = design.layers[layerIndex];
      query = {
        type: "query",
        selects: [],
        from: {
          type: "table",
          table: layer.table,
          alias: "main"
        },
        limit: 1000,
        groupBy: [],
        orderBy: []
      };
      xExpr = this.compileExpr(layer.xExpr);
      colorExpr = this.compileExpr(layer.colorExpr);
      yExpr = this.compileExpr(layer.yExpr);
      if (xExpr) {
        query.selects.push({
          type: "select",
          expr: xExpr,
          alias: "x"
        });
      }
      if (colorExpr) {
        query.selects.push({
          type: "select",
          expr: colorExpr,
          alias: "color"
        });
      }
      if (xExpr || colorExpr) {
        query.orderBy.push({
          ordinal: 1
        });
      }
      if (xExpr && colorExpr) {
        query.orderBy.push({
          ordinal: 2
        });
      }
      if (this.doesLayerNeedGrouping(design, layerIndex)) {
        if (xExpr || colorExpr) {
          query.groupBy.push(1);
        }
        if (xExpr && colorExpr) {
          query.groupBy.push(2);
        }
        if (yExpr) {
          query.selects.push({
            type: "select",
            expr: {
              type: "op",
              op: layer.yAggr,
              exprs: [yExpr]
            },
            alias: "y"
          });
        } else {
          query.selects.push({
            type: "select",
            expr: {
              type: "op",
              op: layer.yAggr,
              exprs: []
            },
            alias: "y"
          });
        }
      } else {
        query.selects.push({
          type: "select",
          expr: yExpr,
          alias: "y"
        });
      }
      if (layer.filter) {
        query.where = this.compileExpr(layer.filter);
      }
      if (extraFilters && extraFilters.length > 0) {
        relevantFilters = _.where(extraFilters, {
          table: layer.table
        });
        if (relevantFilters.length > 0) {
          whereClauses = [];
          if (query.where) {
            whereClauses.push(query.where);
          }
          for (j = 0, len = relevantFilters.length; j < len; j++) {
            filter = relevantFilters[j];
            whereClauses.push(this.compileExpr(filter));
          }
          if (whereClauses.length > 1) {
            query.where = {
              type: "op",
              op: "and",
              exprs: whereClauses
            };
          } else {
            query.where = whereClauses[0];
          }
        }
      }
      queries["layer" + layerIndex] = query;
    }
    return queries;
  };

  LayeredChartCompiler.prototype.mapValue = function(expr, value) {
    var item, items;
    if (value && this.exprBuilder.getExprType(expr) === "enum") {
      items = this.exprBuilder.getExprValues(expr);
      item = _.findWhere(items, {
        id: value
      });
      if (item) {
        return item.name;
      }
    }
    return value;
  };

  LayeredChartCompiler.prototype.getColumns = function(design, data, dataMap) {
    var colorVal, colorValues, columns, i, j, k, l, layer, layerIndex, len, len1, len2, len3, len4, len5, m, n, o, p, ref, ref1, ref2, ref3, row, val, xCategorical, xPresent, xValues, xcolumn, ycolumn;
    if (dataMap == null) {
      dataMap = {};
    }
    columns = [];
    xCategorical = this.isExprCategorical(design.layers[0].xExpr);
    xPresent = design.layers[0].xExpr != null;
    xValues = [];
    for (layerIndex = i = 0, ref = design.layers.length; 0 <= ref ? i < ref : i > ref; layerIndex = 0 <= ref ? ++i : --i) {
      layer = design.layers[layerIndex];
      xValues = _.union(xValues, _.pluck(data["layer" + layerIndex], "x"));
    }
    for (layerIndex = j = 0, ref1 = design.layers.length; 0 <= ref1 ? j < ref1 : j > ref1; layerIndex = 0 <= ref1 ? ++j : --j) {
      layer = design.layers[layerIndex];
      if (layer.colorExpr) {
        colorValues = _.uniq(_.pluck(data["layer" + layerIndex], "color"));
        if (xCategorical) {
          for (k = 0, len = colorValues.length; k < len; k++) {
            colorVal = colorValues[k];
            xcolumn = ["layer" + layerIndex + ":" + colorVal + ":x"];
            ycolumn = ["layer" + layerIndex + ":" + colorVal + ":y"];
            for (l = 0, len1 = xValues.length; l < len1; l++) {
              val = xValues[l];
              xcolumn.push(this.mapValue(layer.xExpr, val));
              row = _.findWhere(data["layer" + layerIndex], {
                x: val,
                color: colorVal
              });
              if (row) {
                ycolumn.push(row.y);
                dataMap[ycolumn[0] + "-" + (ycolumn.length - 2)] = {
                  layerIndex: layerIndex,
                  row: row
                };
              } else {
                ycolumn.push(null);
              }
            }
            columns.push(xcolumn);
            columns.push(ycolumn);
          }
        } else {
          for (m = 0, len2 = colorValues.length; m < len2; m++) {
            colorVal = colorValues[m];
            if (xPresent) {
              xcolumn = ["layer" + layerIndex + ":" + colorVal + ":x"];
            }
            ycolumn = ["layer" + layerIndex + ":" + colorVal + ":y"];
            ref2 = data["layer" + layerIndex];
            for (n = 0, len3 = ref2.length; n < len3; n++) {
              row = ref2[n];
              if (row.color === colorVal) {
                if (xPresent) {
                  xcolumn.push(this.mapValue(layer.xExpr, row.x));
                }
                ycolumn.push(row.y);
                dataMap[ycolumn[0] + "-" + (ycolumn.length - 2)] = {
                  layerIndex: layerIndex,
                  row: row
                };
              }
            }
            if (xPresent) {
              columns.push(xcolumn);
            }
            columns.push(ycolumn);
          }
        }
      } else {
        if (xCategorical) {
          xcolumn = ["layer" + layerIndex + ":x"];
          ycolumn = ["layer" + layerIndex + ":y"];
          for (o = 0, len4 = xValues.length; o < len4; o++) {
            val = xValues[o];
            xcolumn.push(this.mapValue(layer.xExpr, val));
            row = _.findWhere(data["layer" + layerIndex], {
              x: val
            });
            if (row) {
              ycolumn.push(row.y);
              dataMap[ycolumn[0] + "-" + (ycolumn.length - 2)] = {
                layerIndex: layerIndex,
                row: row
              };
            } else {
              ycolumn.push(null);
            }
          }
          columns.push(xcolumn);
          columns.push(ycolumn);
        } else {
          if (xPresent) {
            xcolumn = ["layer" + layerIndex + ":x"];
          }
          ycolumn = ["layer" + layerIndex + ":y"];
          ref3 = data["layer" + layerIndex];
          for (p = 0, len5 = ref3.length; p < len5; p++) {
            row = ref3[p];
            if (xPresent) {
              xcolumn.push(this.mapValue(layer.xExpr, row.x));
            }
            ycolumn.push(row.y);
            dataMap[ycolumn[0] + "-" + (ycolumn.length - 2)] = {
              layerIndex: layerIndex,
              row: row
            };
          }
          if (xPresent) {
            columns.push(xcolumn);
          }
          columns.push(ycolumn);
        }
      }
    }
    return columns;
  };

  LayeredChartCompiler.prototype.getXs = function(columns) {
    var col, i, len, xcol, xs;
    xs = {};
    for (i = 0, len = columns.length; i < len; i++) {
      col = columns[i];
      if (col[0].match(/:y$/)) {
        xcol = col[0].replace(/:y$/, ":x");
        if (_.any(columns, function(c) {
          return c[0] === xcol;
        })) {
          xs[col[0]] = xcol;
        }
      }
    }
    return xs;
  };

  LayeredChartCompiler.prototype.getNames = function(design, data) {
    var colorVal, colorValues, i, j, layer, layerIndex, len, names, ref;
    names = {};
    for (layerIndex = i = 0, ref = design.layers.length; 0 <= ref ? i < ref : i > ref; layerIndex = 0 <= ref ? ++i : --i) {
      layer = design.layers[layerIndex];
      if (layer.colorExpr) {
        colorValues = _.uniq(_.pluck(data["layer" + layerIndex], "color"));
        for (j = 0, len = colorValues.length; j < len; j++) {
          colorVal = colorValues[j];
          names["layer" + layerIndex + ":" + colorVal + ":y"] = this.mapValue(layer.colorExpr, colorVal);
        }
      } else {
        names["layer" + layerIndex + ":y"] = layer.name || ("Series " + (layerIndex + 1));
      }
    }
    return names;
  };

  LayeredChartCompiler.prototype.getTypes = function(design, columns) {
    var column, i, layerIndex, len, types;
    types = {};
    for (i = 0, len = columns.length; i < len; i++) {
      column = columns[i];
      if (column[0].match(/:y$/)) {
        layerIndex = parseInt(column[0].match(/^layer(\d+)/)[1]);
        types[column[0]] = design.layers[layerIndex].type || design.type;
      }
    }
    return types;
  };

  LayeredChartCompiler.prototype.getGroups = function(design, columns) {
    var column, group, groups, i, j, layer, layerIndex, len, ref;
    groups = [];
    for (layerIndex = i = 0, ref = design.layers.length; 0 <= ref ? i < ref : i > ref; layerIndex = 0 <= ref ? ++i : --i) {
      layer = design.layers[layerIndex];
      if (layer.stacked) {
        group = [];
        for (j = 0, len = columns.length; j < len; j++) {
          column = columns[j];
          if (column[0].match("^layer" + layerIndex + ":.*:y$")) {
            group.push(column[0]);
          }
        }
        groups.push(group);
      }
    }
    return groups;
  };

  LayeredChartCompiler.prototype.getXAxisType = function(design) {
    switch (this.exprBuilder.getExprType(design.layers[0].xExpr)) {
      case "text":
      case "enum":
      case "boolean":
        return "category";
      case "date":
        return "timeseries";
      default:
        return "indexed";
    }
  };

  LayeredChartCompiler.prototype.lookupDataPoint = function(data, columns, seriesId, index) {
    var colorStr, dataIndex, layerIndex, match, x, xColumn, xColumnId, y;
    layerIndex = parseInt(seriesId.match(/^layer(\d+)/)[1]);
    xColumnId = seriesId.replace(/:y$/, ":x");
    xColumn = _.find(columns, function(c) {
      return c[0] === xColumnId;
    });
    if (xColumn) {
      x = xColumn[index + 1];
    }
    y = _.find(columns, function(c) {
      return c[0] === seriesId;
    })[index + 1];
    match = seriesId.match(/^layer\d+:(.*):y$/);
    if (match) {
      colorStr = match[1];
    }
    dataIndex = _.findIndex(data["layer" + layerIndex], (function(_this) {
      return function(row) {
        if (xColumn && row.x !== x) {
          return false;
        }
        if ((colorStr != null) && ("" + row.color) !== colorStr) {
          return false;
        }
        if (row.y !== y) {
          return false;
        }
        return true;
      };
    })(this));
    if (dataIndex >= 0) {
      return {
        layerIndex: layerIndex,
        dataIndex: dataIndex
      };
    }
    return null;
  };

  LayeredChartCompiler.prototype.createScopeFilter = function(design, layerIndex, row) {
    var expressionBuilder, filters, layer;
    expressionBuilder = new ExpressionBuilder(this.schema);
    layer = design.layers[layerIndex];
    filters = [];
    if (layer.xExpr) {
      filters.push({
        type: "comparison",
        table: layer.table,
        lhs: layer.xExpr,
        op: "=",
        rhs: {
          type: "literal",
          valueType: expressionBuilder.getExprType(layer.xExpr),
          value: row.x
        }
      });
    }
    if (layer.colorExpr) {
      filters.push({
        type: "comparison",
        table: layer.table,
        lhs: layer.colorExpr,
        op: "=",
        rhs: {
          type: "literal",
          valueType: expressionBuilder.getExprType(layer.colorExpr),
          value: row.color
        }
      });
    }
    if (filters.length > 1) {
      return {
        type: "logical",
        table: layer.table,
        op: "and",
        exprs: filters
      };
    } else {
      return filters[0];
    }
  };

  return LayeredChartCompiler;

})();