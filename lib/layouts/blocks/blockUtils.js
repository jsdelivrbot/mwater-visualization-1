var _, uuid;

_ = require('lodash');

uuid = require('node-uuid');

exports.dropBlock = function(rootBlock, sourceBlock, targetBlock, side) {
  var blocks, index, ref;
  if (targetBlock.type === "root" && rootBlock.id === targetBlock.id) {
    blocks = rootBlock.blocks.slice();
    blocks.push(sourceBlock);
    return _.extend({}, rootBlock, {
      blocks: blocks
    });
  }
  if ((ref = rootBlock.type) === 'vertical' || ref === 'root') {
    blocks = rootBlock.blocks;
    index = _.findIndex(blocks, {
      id: targetBlock.id
    });
    if (index >= 0) {
      blocks = blocks.slice();
      switch (side) {
        case "top":
          blocks.splice(index, 0, sourceBlock);
          break;
        case "bottom":
          blocks.splice(index + 1, 0, sourceBlock);
          break;
        case "left":
          blocks.splice(index, 1, {
            id: uuid.v4(),
            type: "horizontal",
            blocks: [sourceBlock, targetBlock]
          });
          break;
        case "right":
          blocks.splice(index, 1, {
            id: uuid.v4(),
            type: "horizontal",
            blocks: [targetBlock, sourceBlock]
          });
      }
      return _.extend({}, rootBlock, {
        blocks: blocks
      });
    } else {
      blocks = _.map(blocks, function(block) {
        return exports.dropBlock(block, sourceBlock, targetBlock, side);
      });
      return _.extend({}, rootBlock, {
        blocks: blocks
      });
    }
  }
  if (rootBlock.type === "horizontal") {
    blocks = rootBlock.blocks;
    index = _.findIndex(blocks, {
      id: targetBlock.id
    });
    if (index >= 0) {
      blocks = blocks.slice();
      switch (side) {
        case "left":
          blocks.splice(index, 0, sourceBlock);
          break;
        case "right":
          blocks.splice(index + 1, 0, sourceBlock);
          break;
        case "top":
          blocks.splice(index, 1, {
            id: uuid.v4(),
            type: "vertical",
            blocks: [sourceBlock, targetBlock]
          });
          break;
        case "bottom":
          blocks.splice(index, 1, {
            id: uuid.v4(),
            type: "vertical",
            blocks: [targetBlock, sourceBlock]
          });
      }
      return _.extend({}, rootBlock, {
        blocks: blocks
      });
    } else {
      blocks = _.map(blocks, function(block) {
        return exports.dropBlock(block, sourceBlock, targetBlock, side);
      });
      return _.extend({}, rootBlock, {
        blocks: blocks
      });
    }
  }
  return rootBlock;
};

exports.updateBlock = function(rootBlock, block) {
  var blocks, ref;
  if ((ref = rootBlock.type) === 'vertical' || ref === 'horizontal' || ref === 'root') {
    blocks = rootBlock.blocks;
    blocks = _.map(blocks, function(b) {
      if (b.id === block.id) {
        return block;
      } else {
        return b;
      }
    });
    blocks = _.map(blocks, function(b) {
      return exports.updateBlock(b, block);
    });
    return _.extend({}, rootBlock, {
      blocks: blocks
    });
  }
  return rootBlock;
};

exports.removeBlock = function(rootBlock, block) {
  var blocks, ref;
  if ((ref = rootBlock.type) === 'vertical' || ref === 'horizontal' || ref === 'root') {
    blocks = rootBlock.blocks;
    blocks = _.filter(blocks, function(b) {
      return b.id !== block.id;
    });
    blocks = _.compact(_.map(blocks, function(b) {
      return exports.removeBlock(b, block);
    }));
    if (blocks.length === 0 && rootBlock.type !== "root") {
      return null;
    }
    return _.extend({}, rootBlock, {
      blocks: blocks
    });
  }
  return rootBlock;
};