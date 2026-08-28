const notFoundHandler = (req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`
  });
};

const errorHandler = (err, req, res, next) => {
  // eslint-disable-next-line no-console
  console.error(err);
  if (res.headersSent) {
    return next(err);
  }
  return res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || "Something went wrong."
  });
};

module.exports = { notFoundHandler, errorHandler };
