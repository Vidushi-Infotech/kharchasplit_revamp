/**
 * Global error handler middleware
 */
const errorHandler = (err, req, res, next) => {
  console.error('Error:', err);

  // Default error
  let status = 500;
  let message = 'Internal server error';

  // Handle specific error types
  if (err.name === 'ValidationError') {
    status = 400;
    message = err.message;
  } else if (err.name === 'UnauthorizedError') {
    status = 401;
    message = 'Unauthorized';
  } else if (err.code === '23505') {
    // PostgreSQL unique constraint violation
    status = 409;
    message = 'Resource already exists';
  } else if (err.code === '23503') {
    // PostgreSQL foreign key violation
    status = 400;
    message = 'Invalid reference';
  } else if (err.code === '23502') {
    // PostgreSQL not null violation
    status = 400;
    message = 'Required field missing';
  } else if (err.type === 'entity.too.large') {
    // express.json() body limit exceeded
    status = 413;
    message = 'Request body too large. Try a smaller image.';
  } else if (err.type === 'entity.parse.failed') {
    // Malformed JSON body: the client's fault, not a 500.
    status = 400;
    message = 'Invalid JSON in request body';
  } else {
    // Errors that carry their own 4xx status (body-parser, http-errors).
    const own = err.status || err.statusCode;
    if (own >= 400 && own < 500) status = own;
    if (err.message) message = err.message;
  }

  // Stack traces and raw 5xx messages only on a developer's machine: any
  // other NODE_ENV (production, unset, a typo) gets the sanitised reply.
  const isDev = process.env.NODE_ENV === 'development';
  if (!isDev && status >= 500) {
    message = 'Internal server error';
  }

  res.status(status).json({
    success: false,
    error: message,
    ...(isDev && err.stack ? { stack: err.stack } : {}),
  });
};

/**
 * 404 handler
 */
const notFound = (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found',
  });
};

export {
  errorHandler,
  notFound,
};
