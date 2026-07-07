const tagRegex = /<\/?(?:i|b|u|c|font|v)(?:\s+[^>]*)?>/gi;
const braceRegex = /\{\\[^}]*\}/g;

function escapeSubHTML(str) {
  const cleaned = str
    .replace(tagRegex, '')
    .replace(braceRegex, '')
    .replace(/\\N/gi, '\n')
    .replace(/\\h/gi, ' ')
    .trim();
  return cleaned;
}
console.log(escapeSubHTML('<Sighs> I dont know.'));
console.log(escapeSubHTML('I am <so> happy.'));
console.log(escapeSubHTML('{\\an8}Hello there'));
console.log(escapeSubHTML('{He sighs} Wow.'));
console.log(escapeSubHTML('<i>Italics</i>'));
console.log(escapeSubHTML('<font color="#ff0000">Red</font>'));
