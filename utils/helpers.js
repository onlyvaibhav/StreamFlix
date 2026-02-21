function parseRangeHeader(range, fileSize) {
  if (!range) return null;

  const parts = range.replace(/bytes=/, '').split('-');
  const start = parseInt(parts[0], 10);
  const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

  return {
    start: isNaN(start) ? 0 : start,
    end: isNaN(end) ? fileSize - 1 : Math.min(end, fileSize - 1)
  };
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports = { parseRangeHeader, sleep };