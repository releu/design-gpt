// Check snippet text nodes
const f = figma.currentPage.findOne(n => n.name.startsWith('[v'));
const scroll = f.children[0].children.find(c => c.name === 'Scroll');
const snippet = scroll.children.find(c => c.name === 'Block / Snippet');

function allTextNodes(node) {
  const texts = [];
  if (node.type === 'TEXT') {
    texts.push({ name: node.name, text: node.characters.substring(0, 60) });
  }
  if ('children' in node) {
    for (const c of node.children) texts.push(...allTextNodes(c));
  }
  return texts;
}

JSON.stringify(allTextNodes(snippet), null, 2);
