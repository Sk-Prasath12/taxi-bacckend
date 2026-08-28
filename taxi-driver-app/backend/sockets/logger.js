const format = (level, message, meta) => {
  const ts = new Date().toISOString();
  const suffix = meta ? ` ${JSON.stringify(meta)}` : "";
  return `[socket][${level}] ${ts} ${message}${suffix}`;
};

const logger = {
  info: (message, meta) => console.log(format("info", message, meta)),
  warn: (message, meta) => console.warn(format("warn", message, meta)),
  error: (message, meta) => console.error(format("error", message, meta))
};

module.exports = { logger };
